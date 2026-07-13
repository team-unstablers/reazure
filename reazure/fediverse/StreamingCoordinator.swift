//
//  StreamingCoordinator.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation
import Network

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

/// Observes whether the network path is usable, so the coordinator can
/// short-circuit its exponential backoff the moment connectivity is restored.
/// Abstracted behind a protocol — like `WebSocketProviding` / `ReconnectScheduling`
/// — so tests can drive path transitions without a real interface.
protocol PathMonitoring: AnyObject {
    /// Begins monitoring. `onChange` is invoked on the main thread with the
    /// current reachability on every path update, including the initial state.
    /// Call at most once per instance.
    func start(onChange: @escaping (Bool) -> Void)
    /// Stops monitoring. Idempotent.
    func cancel()
}

/// Live monitor backed by `NWPathMonitor`. A fresh instance is built per account
/// session because `NWPathMonitor` is single-use — it cannot be restarted after
/// `cancel()`.
final class NWPathMonitorAdaptor: PathMonitoring {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "pl.unstabler.reazure.network-path-monitor")

    func start(onChange: @escaping (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            let satisfied = path.status == .satisfied
            // Hop to main so the coordinator's main-thread confinement holds.
            DispatchQueue.main.async {
                onChange(satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.pathUpdateHandler = nil
        monitor.cancel()
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
        /// REST-refresh the timelines to recover what the stream missed while it was
        /// down. Run on every path that reopens the stream, since streaming delivers
        /// only what arrives after it connects and never replays the gap.
        var backfill: () -> Void
    }

    private let account: Account
    private let socketProvider: WebSocketProviding
    private let scheduler: ReconnectScheduling
    private let configurationProvider: (Account) async throws -> FediverseServerConfiguration
    private let pathMonitor: PathMonitoring
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

    /// Last reachability reported by the path monitor. Seeded optimistically so
    /// the initial (already-satisfied) callback is a no-op and startup never opens
    /// a second connection racing the one `start()` kicks off.
    private var pathSatisfied: Bool = true

    init(account: Account,
         socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() },
         pathMonitor: PathMonitoring = NWPathMonitorAdaptor(),
         maxAttempts: Int = 10,
         baseDelay: TimeInterval = 1,
         maxDelay: TimeInterval = 30,
         callbacks: Callbacks) {
        self.account = account
        self.socketProvider = socketProvider
        self.scheduler = scheduler
        self.configurationProvider = configurationProvider
        self.pathMonitor = pathMonitor
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.callbacks = callbacks
    }

    // MARK: - lifecycle

    /// Starts network-path monitoring, fetches the server configuration, then
    /// opens the first connection. Safe to call once per coordinator; the facade
    /// builds a fresh coordinator per account.
    func start() {
        pathMonitor.start { [weak self] satisfied in
            self?.handlePathChange(satisfied: satisfied)
        }
        loadConfigurationThenOpen()
    }

    /// Tears down the connection, stops path monitoring, and cancels any pending
    /// reconnect. Idempotent. After this the coordinator is inert — no scheduled
    /// work or path callback can reopen a socket.
    func stop() {
        stopped = true
        pathMonitor.cancel()
        cancelPendingReconnect()

        streamingClient?.delegate = nil
        streamingClient?.stop()
        streamingClient = nil

        callbacks.stateDidChange(.disconnected)
    }

    /// Fetches the (one-time) server configuration off-main, then hops back to
    /// main to cache it, mirror it to the facade, and open the connection. Shared
    /// by `start()` and `reconnectNow()` (the latter re-runs it if the launch-time
    /// fetch never succeeded, e.g. the app started offline).
    private func loadConfigurationThenOpen() {
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

    // MARK: - connection

    /// Builds the `StreamingClient` lazily (reused across reconnects) and starts
    /// it with the cached configuration. Main thread only.
    private func openConnection() {
        guard !stopped, let configuration else { return }

        let client: StreamingClient
        if let existing = streamingClient {
            client = existing
        } else {
            let created = StreamingClient(using: account,
                                          socketProvider: socketProvider,
                                          adapter: account.server.streamingAdapter(for: account))
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

            self.callbacks.backfill()
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

    // MARK: - connectivity-driven reconnect

    /// Reachability transition from the path monitor. Only an
    /// `unsatisfied → satisfied` edge (connectivity restored) forces a reconnect;
    /// the initial callback and Wi-Fi↔cellular handoffs are inert.
    private func handlePathChange(satisfied: Bool) {
        guard !stopped else { return }

        let wasSatisfied = pathSatisfied
        pathSatisfied = satisfied

        guard satisfied, !wasSatisfied else { return }
        reconnectNow()
    }

    /// Short-circuits the exponential backoff and forces an immediate reconnect,
    /// used when connectivity is restored or the app returns to the foreground.
    /// A restored network is treated as a clean slate, so the attempt budget is
    /// reset even mid-attempt; a healthy or already-dialing connection is left
    /// untouched so a mere path change never churns a working socket.
    func reconnectNow() {
        guard !stopped else { return }

        // Backfill first, ahead of the socket-state check below. Both callers — a
        // foreground return and a restored network path — imply the stream was away
        // for some interval, and streaming never replays what it missed while away.
        // The socket's *own* view of its health cannot rule that gap out: a suspend
        // can leave it reporting `.connected` on a connection that is already dead,
        // and returning early on that would drop the recovery entirely. A redundant
        // refresh merely dedupes to zero new entries; a permanently missing status
        // has no such second chance.
        callbacks.backfill()

        attempt = 0
        cancelPendingReconnect()

        switch streamingClient?.state {
        case .connected, .connecting:
            return
        case .disconnected, .none:
            break
        }

        if configuration == nil {
            // The launch-time configuration fetch never succeeded (e.g. started
            // offline); redo it, which opens the connection on completion.
            loadConfigurationThenOpen()
        } else {
            // Tear down a possibly half-open socket before reopening, mirroring the
            // backoff path so the identity guard has exactly one socket to fence.
            streamingClient?.stop()
            openConnection()
        }
    }
}

extension StreamingCoordinator: StreamingClientDelegate {
    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient) {
        guard client === streamingClient else { return }

        // A decoded event proves the connection is doing useful work — this, not
        // the bare `.connected` handshake, is what resets the reconnect backoff.
        // A server that completes the handshake and then immediately drops without
        // ever delivering an event keeps backing off toward the attempt cap
        // instead of hammering at the base delay forever.
        attempt = 0

        callbacks.didReceiveEvent(event)
    }

    func didStateChange(state: StreamingState, client: StreamingClient) {
        // Ignore a superseded client's late callback.
        guard client === streamingClient else { return }

        callbacks.stateDidChange(state)

        switch state {
        case .connected:
            // Handshake completion alone does not reset the backoff (see
            // `didReceive` — reset is gated on an actual event); just drop any
            // now-moot pending reconnect.
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
