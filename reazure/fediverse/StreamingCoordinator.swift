//
//  StreamingCoordinator.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

/// Schedules the single pending reconnect attempt after a delay. Abstracted so
/// tests can drive the reconnect loop deterministically instead of waiting on a
/// real clock.
protocol ReconnectScheduling {
    /// Schedules `work` to run after `delay` seconds. Cancellation is the
    /// caller's responsibility via the `DispatchWorkItem` it retains.
    func schedule(_ work: DispatchWorkItem, after delay: TimeInterval)
}

/// Live scheduler backed by the main queue, so the reconnect fires on the same
/// thread the coordinator confines its state to.
struct MainQueueReconnectScheduler: ReconnectScheduling {
    func schedule(_ work: DispatchWorkItem, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

/// Owns the streaming lifecycle for a single account: the `StreamingClient`, the
/// one-time configuration fetch/cache, the `streamingState`, and — crucially —
/// the reconnect policy that used to live inline in `SharedClient.didStateChange`.
///
/// The facade (`SharedClient`) keeps the reactive `@Published` surface
/// (`streamingState`, `configuration`) that views subscribe to; this coordinator
/// mirrors into it through `Callbacks`, so no view wiring changes. Decoded
/// streaming events are handed back through `Callbacks.didReceiveEvent` so the
/// facade still owns event ingest (timeline prepend + notification presentation).
///
/// ## Threading
/// State is confined to the main thread. Every `StreamingClientDelegate` callback
/// arrives on Starscream's main callback queue, the reconnect scheduler fires on
/// the main queue, and the only off-main entry — the async configuration fetch —
/// hops back to main before touching any state. No `@Published` value is ever
/// read or written off-main (the former off-main `configuration`/`timeline` read
/// was one of the reconnect defects this type removes).
final class StreamingCoordinator {
    /// Passthrough hooks back into the facade. All invoked on the main thread.
    struct Callbacks {
        /// Mirror the streaming state into the facade `@Published`.
        var stateDidChange: (StreamingState) -> Void
        /// Mirror the fetched server configuration into the facade `@Published`.
        var configurationDidLoad: (FediverseServerConfiguration) -> Void
        /// Hand a decoded streaming event to the facade for ingest.
        var didReceiveEvent: (Mastodon.StreamingEvent) -> Void
        /// Refresh the home timeline over REST just before a reconnect attempt.
        var backfillHome: () -> Void
    }

    private let account: Account
    private let socketProvider: WebSocketProviding
    private let scheduler: ReconnectScheduling
    private let configurationProvider: (Account) async throws -> FediverseServerConfiguration
    private let callbacks: Callbacks

    /// Backoff ceiling on the number of consecutive reconnect attempts. Reset to
    /// zero on a successful `.connected`.
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval

    // MARK: main-thread confined state

    private var streamingClient: StreamingClient?
    private var configuration: FediverseServerConfiguration?

    /// The single in-flight reconnect. Holding exactly one at a time is the
    /// single-flight guard that stops nested timers from opening several sockets.
    private var reconnectWorkItem: DispatchWorkItem?
    private var attempt: Int = 0

    /// Set once `stop()` runs so a late delegate callback or an already-scheduled
    /// reconnect can never resurrect a torn-down connection (the zombie-client
    /// defect on account switch).
    private var stopped: Bool = false

    init(account: Account,
         socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() },
         maxAttempts: Int = 10,
         baseDelay: TimeInterval = 1,
         maxDelay: TimeInterval = 30,
         callbacks: Callbacks) {
        self.account = account
        self.socketProvider = socketProvider
        self.scheduler = scheduler
        self.configurationProvider = configurationProvider
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.callbacks = callbacks
    }

    // MARK: - lifecycle

    /// Fetches the server configuration, then opens the first connection. Safe to
    /// call once per coordinator; the facade builds a fresh coordinator per
    /// account.
    func start() {
        Task { [weak self] in
            guard let self else { return }
            // FIXME: surface configuration failures instead of silently giving up.
            guard let configuration = try? await self.configurationProvider(self.account) else {
                return
            }

            DispatchQueue.main.async {
                guard !self.stopped else { return }
                self.configuration = configuration
                self.callbacks.configurationDidLoad(configuration)
                self.openConnection()
            }
        }
    }

    /// Tears down the connection and cancels any pending reconnect. Idempotent.
    /// After this the coordinator is inert — no scheduled work can reopen a socket.
    func stop() {
        stopped = true
        cancelPendingReconnect()

        streamingClient?.delegate = nil
        streamingClient?.stop()
        streamingClient = nil

        callbacks.stateDidChange(.disconnected)
    }

    // MARK: - connection

    /// Builds the `StreamingClient` lazily (reused across reconnects) and starts
    /// it with the cached configuration. Main thread only.
    private func openConnection() {
        guard !stopped, let configuration else { return }

        let client: StreamingClient
        if let existing = streamingClient {
            client = existing
        } else {
            let created = StreamingClient(using: account, socketProvider: socketProvider)
            created.delegate = self
            streamingClient = created
            client = created
        }

        client.start(configuration)
    }

    // MARK: - reconnect policy

    private func scheduleReconnect(for client: StreamingClient) {
        // Identity guard: only the current client may drive a reconnect.
        guard !stopped, client === streamingClient else { return }
        // Single-flight: never stack a second pending reconnect.
        guard reconnectWorkItem == nil else { return }
        // Attempt cap: stop hammering a server that keeps rejecting us.
        guard attempt < maxAttempts else {
            print("streaming: reconnect attempt cap (\(maxAttempts)) reached; giving up")
            return
        }

        let delay = reconnectDelay(forAttempt: attempt)
        attempt += 1

        // Capture `client` weakly: the fire-time guard already tolerates it being
        // gone (nil !== the live client), so a strong capture would only pin the
        // superseded client + socket alive until the scheduler's deadline.
        let work = DispatchWorkItem { [weak self, weak client] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            // Re-check at fire time: the account may have been torn down or
            // superseded while this attempt was pending.
            guard !self.stopped, let client, client === self.streamingClient else { return }

            // Tear down the previous socket before reopening (restores the
            // pre-refactor `client.stop()`): a socket dropped via `.error` is
            // otherwise left half-open, and this keeps a single live socket per
            // client so the identity guard has exactly one socket to fence.
            client.stop()

            self.callbacks.backfillHome()
            self.openConnection()
        }

        reconnectWorkItem = work
        scheduler.schedule(work, after: delay)
    }

    private func cancelPendingReconnect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
    }

    /// Capped exponential backoff: `baseDelay · 2^attempt`, clamped to `maxDelay`.
    private func reconnectDelay(forAttempt attempt: Int) -> TimeInterval {
        let raw = baseDelay * pow(2.0, Double(attempt))
        return min(maxDelay, raw)
    }
}

extension StreamingCoordinator: StreamingClientDelegate {
    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient) {
        guard client === streamingClient else { return }
        callbacks.didReceiveEvent(event)
    }

    func didStateChange(state: StreamingState, client: StreamingClient) {
        // Ignore a superseded client's late callback.
        guard client === streamingClient else { return }

        callbacks.stateDidChange(state)

        switch state {
        case .connected:
            // Success resets the backoff; any stale pending reconnect is moot.
            attempt = 0
            cancelPendingReconnect()
        case .disconnected:
            scheduleReconnect(for: client)
        case .connecting:
            break
        }
    }

    func streamingClient(_ client: StreamingClient, didFailWith error: StreamingClientError) {
        guard client === streamingClient else { return }
        // The reconnect is driven by the accompanying `.disconnected` transition;
        // the failure is surfaced here for diagnostics and future policy.
        print("streaming: transport failure: \(error)")
    }
}
