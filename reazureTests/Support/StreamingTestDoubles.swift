//
//  StreamingTestDoubles.swift
//  reazureTests
//
//  Test doubles for the streaming surgery (roadmap Phase 3). They let the
//  streaming state machine and the reconnect controller be exercised without a
//  live network: a synthetic `WebSocket` whose events the test drives, a factory
//  that hands it out, a recording delegate, and a manual reconnect scheduler.
//

import Foundation
import Starscream

@testable import reazure

// MARK: - WebSocket

/// A synthetic `WebSocketConnecting` with no networking. Records the writes and
/// lifecycle calls the production code makes, and lets a test push
/// `WebSocketEvent`s back through the delegate it was assigned.
final class FakeWebSocket: WebSocketConnecting {
    weak var delegate: WebSocketDelegate?

    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var sentPongs = 0

    func connect() {
        connectCount += 1
    }

    func disconnect(closeCode: UInt16) {
        disconnectCount += 1
    }

    func write(string: String, completion: (() -> ())?) { completion?() }
    func write(stringData: Data, completion: (() -> ())?) { completion?() }
    func write(data: Data, completion: (() -> ())?) { completion?() }
    func write(ping: Data, completion: (() -> ())?) { completion?() }
    func write(pong: Data, completion: (() -> ())?) {
        sentPongs += 1
        completion?()
    }

    /// Delivers an event to the assigned delegate exactly as Starscream would.
    func emit(_ event: WebSocketEvent) {
        delegate?.didReceive(event: event, client: self)
    }
}

/// Hands out `FakeWebSocket`s and records every one it created so a test can
/// count reconnect attempts (each `start()` builds a fresh socket).
final class FakeWebSocketProvider: WebSocketProviding {
    private(set) var createdSockets: [FakeWebSocket] = []
    private(set) var lastRequest: URLRequest?

    var latest: FakeWebSocket? { createdSockets.last }

    func webSocket(with request: URLRequest) -> WebSocketConnecting {
        lastRequest = request
        let socket = FakeWebSocket()
        createdSockets.append(socket)
        return socket
    }
}

// MARK: - Delegate

/// Records the callbacks a `StreamingClient` routes to its delegate.
final class RecordingStreamingDelegate: StreamingClientDelegate {
    private(set) var events: [Mastodon.StreamingEvent] = []
    private(set) var states: [StreamingState] = []
    private(set) var failures: [StreamingClientError] = []

    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient) {
        events.append(event)
    }

    func didStateChange(state: StreamingState, client: StreamingClient) {
        states.append(state)
    }

    func streamingClient(_ client: StreamingClient, didFailWith error: StreamingClientError) {
        failures.append(error)
    }
}

// MARK: - Reconnect scheduler

/// A `ReconnectScheduling` that never touches a real clock: it records each
/// scheduled work item with its requested delay so a test can inspect the
/// backoff sequence and fire pending work deterministically.
final class ManualReconnectScheduler: ReconnectScheduling {
    private(set) var scheduled: [(work: DispatchWorkItem, delay: TimeInterval)] = []

    var pendingCount: Int { scheduled.count }
    var delays: [TimeInterval] { scheduled.map { $0.delay } }

    func schedule(_ work: DispatchWorkItem, after delay: TimeInterval) {
        scheduled.append((work, delay))
    }

    /// Runs the oldest pending work item (skipping it if cancelled), mirroring
    /// how `DispatchQueue.asyncAfter` drops a cancelled item.
    func fireNext() {
        guard !scheduled.isEmpty else { return }
        let next = scheduled.removeFirst()
        if !next.work.isCancelled {
            next.work.perform()
        }
    }
}

// MARK: - Path monitor

/// A `PathMonitoring` with no real interface: records `start`/`cancel` and lets a
/// test push reachability transitions through the stored handler, exactly as the
/// live monitor would deliver them on the main thread.
final class FakePathMonitor: PathMonitoring {
    private(set) var started = false
    private(set) var cancelled = false
    private var onChange: ((Bool) -> Void)?

    func start(onChange: @escaping (Bool) -> Void) {
        started = true
        self.onChange = onChange
    }

    func cancel() {
        cancelled = true
    }

    /// Delivers a reachability change to the coordinator.
    func emit(satisfied: Bool) {
        onChange?(satisfied)
    }
}

// MARK: - Fixtures

extension Account {
    /// A throwaway account for streaming tests. The streaming URL derived from
    /// `streamingEndpoint` never reaches the fake socket, so the host is
    /// arbitrary as long as it forms a valid URL.
    static func fixture(server: String = "streaming.example.com") -> Account {
        Account(id: "acc-stream",
                username: "tester",
                server: .mastodon(address: server),
                accessToken: "token")
    }
}

extension FediverseServerConfiguration {
    static func fixture(streamingEndpoint: String = "wss://streaming.example.com",
                        maxPostLength: Int = 500) -> FediverseServerConfiguration {
        FediverseServerConfiguration(streamingEndpoint: streamingEndpoint,
                                     maxPostLength: maxPostLength)
    }
}
