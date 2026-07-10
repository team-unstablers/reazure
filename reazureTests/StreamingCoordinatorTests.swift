//
//  StreamingCoordinatorTests.swift
//  reazureTests
//
//  Regression coverage for `StreamingCoordinator` (roadmap step 3.2) — the
//  highest-risk extraction in the decomposition. These pin the reconnect policy
//  that replaces the inline `SharedClient.didStateChange` loop and, in
//  particular, that the four historical reconnect defects stay fixed:
//
//    1. backoff / attempt cap / single-flight guard    (no unbounded hammering)
//    2. no re-entrant `.disconnected` → nested timers   (single-flight)
//    3. state confined to main (no off-main @Published read)
//    4. no zombie client after teardown                 (stop cancels + guards)
//
//  Driving a synthetic `WebSocket` (from `StreamingTestDoubles`) plus a manual
//  reconnect scheduler makes the whole loop deterministic — no real clock, no
//  network. Tests are `@MainActor` so the delegate callbacks and the scheduler
//  run on the thread the coordinator confines its state to.
//

import Foundation
import Testing
import Starscream

@testable import reazure

@MainActor
struct StreamingCoordinatorTests {

    // MARK: - harness

    /// Captures every passthrough the coordinator mirrors back to the facade.
    private final class FacadeSpy {
        var states: [StreamingState] = []
        var configurations: [FediverseServerConfiguration] = []
        var events: [Mastodon.StreamingEvent] = []
        var backfillCount = 0

        func callbacks() -> StreamingCoordinator.Callbacks {
            StreamingCoordinator.Callbacks(
                stateDidChange: { self.states.append($0) },
                configurationDidLoad: { self.configurations.append($0) },
                didReceiveEvent: { self.events.append($0) },
                backfillHome: { self.backfillCount += 1 }
            )
        }
    }

    /// Holds the coordinator plus its fakes. Keeping the harness in scope keeps
    /// the coordinator (and thus its `StreamingClient`) alive, so the socket's
    /// weak delegate stays valid for the duration of the test.
    private struct Harness {
        let coordinator: StreamingCoordinator
        let provider: FakeWebSocketProvider
        let scheduler: ManualReconnectScheduler
        let spy: FacadeSpy

        /// The most recently created socket — each `start()`/reconnect makes a
        /// fresh one, so this is always the live connection under test.
        var socket: FakeWebSocket? { provider.latest }
    }

    /// Builds a coordinator wired to fakes, starts it, and awaits the first
    /// socket (the async configuration fetch hops to main before connecting).
    private func startedHarness(maxAttempts: Int = 10) async -> Harness {
        let provider = FakeWebSocketProvider()
        let scheduler = ManualReconnectScheduler()
        let spy = FacadeSpy()
        let coordinator = StreamingCoordinator(
            account: .fixture(),
            socketProvider: provider,
            scheduler: scheduler,
            configurationProvider: { _ in .fixture() },
            maxAttempts: maxAttempts,
            callbacks: spy.callbacks()
        )

        coordinator.start()
        await eventually { provider.createdSockets.count == 1 }
        // Fail loudly if startup never connected — otherwise a negative assertion
        // (`pendingCount == 0`) in a caller would pass vacuously against a nil socket.
        #expect(provider.createdSockets.count == 1)

        return Harness(coordinator: coordinator, provider: provider, scheduler: scheduler, spy: spy)
    }

    /// Spins the main queue until `condition` holds or the bound is hit, letting
    /// the async config fetch's main-hop land without a real clock.
    private func eventually(iterations: Int = 500, _ condition: () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            await flushMainQueue()
        }
    }

    // MARK: - startup

    @Test func start_loadsConfigurationMirrorsItAndConnects() async {
        let h = await startedHarness()

        #expect(h.provider.createdSockets.count == 1)
        #expect(h.socket?.connectCount == 1)
        #expect(h.spy.configurations.count == 1)
        #expect(h.spy.states.contains(.connecting))
    }

    @Test func connectedEvent_isMirroredToFacade() async {
        let h = await startedHarness()

        h.socket?.emit(.connected([:]))

        #expect(h.spy.states.last == .connected)
    }

    @Test func decodedEvent_isForwardedToFacadeIngest() async {
        let h = await startedHarness()

        h.socket?.emit(.text(#"{"event":"update","payload":"x"}"#))

        #expect(h.spy.events.count == 1)
        #expect(h.spy.events.first?.event == "update")
    }

    // MARK: - defect 2: single-flight (no nested timers)

    /// The historical defect: a `.disconnected` re-assignment re-entered the
    /// reconnect path and stacked timers, opening several sockets. A burst of
    /// `.disconnected` events must now yield exactly one pending reconnect.
    @Test func repeatedDisconnects_scheduleAtMostOneReconnect() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))

        h.socket?.emit(.disconnected("a", 1006))
        h.socket?.emit(.disconnected("b", 1006))
        h.socket?.emit(.disconnected("c", 1006))

        #expect(h.scheduler.pendingCount == 1)
    }

    @Test func reconnect_backfillsHomeThenOpensAFreshSocket() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.pendingCount == 1)

        h.scheduler.fireNext()

        #expect(h.spy.backfillCount == 1)
        #expect(h.provider.createdSockets.count == 2)
    }

    // MARK: - defect 1: backoff + attempt cap

    /// Delays follow capped exponential backoff (1, 2, 4, … clamped to 30) across
    /// consecutive failed attempts, rather than a fixed 1s that hammers the server.
    @Test func reconnectDelays_useCappedExponentialBackoff() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))

        var recorded: [TimeInterval] = []
        for _ in 0..<7 {
            h.socket?.emit(.disconnected("x", 1006))
            recorded.append(h.scheduler.delays.last ?? -1)
            h.scheduler.fireNext()   // reopens (.connecting); attempt is not reset
        }

        #expect(recorded == [1, 2, 4, 8, 16, 30, 30])
    }

    /// After `maxAttempts` consecutive failures the coordinator stops scheduling
    /// reconnects instead of retrying forever.
    @Test func reconnect_stopsAfterAttemptCap() async {
        let h = await startedHarness(maxAttempts: 3)
        h.socket?.emit(.connected([:]))

        for _ in 0..<3 {
            h.socket?.emit(.disconnected("x", 1006))
            h.scheduler.fireNext()
        }

        // The 4th drop is past the cap — nothing new is scheduled.
        h.socket?.emit(.disconnected("x", 1006))

        #expect(h.scheduler.pendingCount == 0)
    }

    /// A successful `.connected` resets the backoff, so a later drop starts again
    /// from the base delay rather than continuing to grow.
    @Test func successfulConnect_resetsBackoff() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))

        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.delays.last == 1)
        h.scheduler.fireNext()

        h.socket?.emit(.connected([:]))            // reset
        h.socket?.emit(.disconnected("y", 1006))

        #expect(h.scheduler.delays.last == 1)
    }

    // MARK: - defect 4: no zombie client after teardown

    /// `stop()` cancels the pending reconnect, so firing it opens no socket — the
    /// account-switch zombie-connection defect.
    @Test func stopBeforeReconnectFires_opensNoZombieSocket() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.pendingCount == 1)

        h.coordinator.stop()
        h.scheduler.fireNext()   // cancelled work item — a no-op

        #expect(h.provider.createdSockets.count == 1)
    }

    /// After teardown, a late event from the old socket is dropped (its delegate
    /// was detached), so it can neither reconnect nor mutate the facade.
    @Test func lateEventAfterStop_isIgnored() async {
        let h = await startedHarness()
        let oldSocket = h.socket
        h.socket?.emit(.connected([:]))

        h.coordinator.stop()
        oldSocket?.emit(.disconnected("late", 1006))

        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func stop_mirrorsDisconnectedState() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))

        h.coordinator.stop()

        #expect(h.spy.states.last == .disconnected)
    }

    /// Isolates the cancellation guard: `stop()` must actually cancel the pending
    /// work item, not merely rely on the downstream `stopped`/identity re-checks.
    /// (Without this, deleting `cancelPendingReconnect()` from `stop()` would
    /// leave the end-to-end zombie tests green.)
    @Test func stop_cancelsThePendingReconnectWorkItem() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        let pending = h.scheduler.scheduled.first?.work

        h.coordinator.stop()

        #expect(pending?.isCancelled == true)
    }

    // MARK: - defect 3: main-thread confinement (live scheduler)

    /// Pins D3 against the *real* `MainQueueReconnectScheduler` and the async
    /// configuration hop: both the configuration load and the reconnect work must
    /// run on the main thread. Reverting either to an off-main queue (the original
    /// defect) flips a recorded flag and fails this test.
    @Test func liveScheduler_runsReconnectWorkAndConfigLoadOnMain() async {
        let provider = FakeWebSocketProvider()
        var configOnMain: [Bool] = []
        var backfillOnMain: [Bool] = []

        let coordinator = StreamingCoordinator(
            account: .fixture(),
            socketProvider: provider,
            scheduler: MainQueueReconnectScheduler(),
            configurationProvider: { _ in .fixture() },
            baseDelay: 0.01,
            callbacks: StreamingCoordinator.Callbacks(
                stateDidChange: { _ in },
                configurationDidLoad: { _ in configOnMain.append(Thread.isMainThread) },
                didReceiveEvent: { _ in },
                backfillHome: { backfillOnMain.append(Thread.isMainThread) }
            )
        )

        coordinator.start()
        for _ in 0..<200 where provider.createdSockets.isEmpty {
            await flushMainQueue()
        }
        #expect(provider.createdSockets.count == 1)

        provider.latest?.emit(.connected([:]))
        provider.latest?.emit(.disconnected("x", 1006))   // arms a real asyncAfter reconnect

        // Allow the ~10ms backoff to elapse on the main queue.
        try? await Task.sleep(nanoseconds: 150_000_000)

        #expect(configOnMain == [true])
        #expect(backfillOnMain == [true])
        withExtendedLifetime(coordinator) {}
    }
}
