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
                backfill: { self.backfillCount += 1 }
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
        let pathMonitor: FakePathMonitor
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
        let pathMonitor = FakePathMonitor()
        let spy = FacadeSpy()
        let coordinator = StreamingCoordinator(
            account: .fixture(),
            socketProvider: provider,
            scheduler: scheduler,
            configurationProvider: { _ in .fixture() },
            pathMonitor: pathMonitor,
            maxAttempts: maxAttempts,
            callbacks: spy.callbacks()
        )

        coordinator.start()
        await eventually { provider.createdSockets.count == 1 }
        // Fail loudly if startup never connected — otherwise a negative assertion
        // (`pendingCount == 0`) in a caller would pass vacuously against a nil socket.
        #expect(provider.createdSockets.count == 1)

        return Harness(coordinator: coordinator, provider: provider, scheduler: scheduler, pathMonitor: pathMonitor, spy: spy)
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

    @Test func reconnect_backfillsThenOpensAFreshSocket() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.pendingCount == 1)

        h.scheduler.fireNext()

        #expect(h.spy.backfillCount == 1)
        #expect(h.provider.createdSockets.count == 2)
    }

    // MARK: - backfill on every reopen path

    /// The one that matters most. `reconnectNow()` skips the reconnect when the
    /// socket claims to be healthy — but a socket that survived a suspend can report
    /// `.connected` over a connection that is already dead, and the events missed in
    /// the meantime are gone either way (streaming never replays them). So the
    /// backfill must run *ahead* of that check: gating it on the socket's own view of
    /// its health would silently drop the recovery in exactly the case a foreground
    /// return is meant to handle.
    @Test func reconnectNow_backfillsEvenWhileSocketStillReportsConnected() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        let socketsBefore = h.provider.createdSockets.count

        h.coordinator.reconnectNow()   // app returns to the foreground

        #expect(h.spy.backfillCount == 1)                            // gap recovered
        #expect(h.provider.createdSockets.count == socketsBefore)    // healthy socket left alone
    }

    /// A restored network path is the other way back in, and misses the same window.
    @Test func networkRestore_backfills() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))

        h.pathMonitor.emit(satisfied: false)
        h.pathMonitor.emit(satisfied: true)

        #expect(h.spy.backfillCount == 1)
    }

    /// Signed out / torn down: nothing left to recover into, and a late foreground
    /// return must not resurrect the session.
    @Test func reconnectNow_afterStop_doesNotBackfill() async {
        let h = await startedHarness()
        h.coordinator.stop()

        h.coordinator.reconnectNow()

        #expect(h.spy.backfillCount == 0)
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

    /// Receiving an actual streaming event resets the backoff, so a later drop
    /// starts again from the base delay. The bare `.connected` handshake between
    /// the reconnect and the event does NOT reset it.
    @Test func receivingEvent_resetsBackoff() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))

        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.delays.last == 1)
        h.scheduler.fireNext()

        h.socket?.emit(.connected([:]))            // handshake alone: no reset
        h.socket?.emit(.text(#"{"event":"update","payload":"x"}"#))  // real event: reset
        h.socket?.emit(.disconnected("y", 1006))

        #expect(h.scheduler.delays.last == 1)
    }

    /// The flap defect: a server that completes the handshake and then immediately
    /// drops, over and over, delivering no events. `.connected` must NOT reset the
    /// backoff, so the delay grows and the attempt cap is reached — rather than
    /// hammering at the base delay indefinitely.
    @Test func handshakeFlapWithoutEvents_backsOffAndReachesCap() async {
        let h = await startedHarness(maxAttempts: 4)

        var delays: [TimeInterval] = []
        for _ in 0..<4 {
            h.socket?.emit(.connected([:]))          // handshake completes...
            h.socket?.emit(.disconnected("x", 1006)) // ...then drops, no event delivered
            delays.append(h.scheduler.delays.last ?? -1)
            h.scheduler.fireNext()
        }

        #expect(delays == [1, 2, 4, 8])

        // 5th flap is past the cap (attempt == maxAttempts) — nothing scheduled.
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.pendingCount == 0)
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
            pathMonitor: FakePathMonitor(),
            baseDelay: 0.01,
            callbacks: StreamingCoordinator.Callbacks(
                stateDidChange: { _ in },
                configurationDidLoad: { _ in configOnMain.append(Thread.isMainThread) },
                didReceiveEvent: { _ in },
                backfill: { backfillOnMain.append(Thread.isMainThread) }
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

    // MARK: - connectivity-driven reconnect

    /// The give-up recovery: after the attempt cap is reached the coordinator no
    /// longer schedules reconnects, so a restored network is the only way back —
    /// an `unsatisfied → satisfied` edge forces a fresh connect and resets the budget.
    @Test func networkRestore_afterGiveUp_reconnects() async {
        let h = await startedHarness(maxAttempts: 3)
        h.socket?.emit(.connected([:]))

        for _ in 0..<3 {
            h.socket?.emit(.disconnected("x", 1006))
            h.scheduler.fireNext()
        }
        h.socket?.emit(.disconnected("x", 1006))   // past the cap — nothing scheduled
        #expect(h.scheduler.pendingCount == 0)
        let socketsBeforeRestore = h.provider.createdSockets.count

        // Connectivity drops, then returns: the restore edge reconnects immediately.
        h.pathMonitor.emit(satisfied: false)
        h.pathMonitor.emit(satisfied: true)

        #expect(h.provider.createdSockets.count == socketsBeforeRestore + 1)

        // The budget was reset, so a subsequent drop backs off from the base delay.
        h.socket?.emit(.disconnected("y", 1006))
        #expect(h.scheduler.delays.last == 1)
    }

    /// Restoring connectivity while a backoff timer is pending cancels the wait and
    /// reconnects now, instead of idling until the (up to 30s) delay elapses.
    @Test func networkRestore_duringBackoff_skipsWaitAndReconnects() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        h.socket?.emit(.disconnected("x", 1006))
        #expect(h.scheduler.pendingCount == 1)
        let pending = h.scheduler.scheduled.first?.work
        let socketsBefore = h.provider.createdSockets.count

        h.pathMonitor.emit(satisfied: false)
        h.pathMonitor.emit(satisfied: true)

        #expect(pending?.isCancelled == true)                          // backoff timer cancelled
        #expect(h.provider.createdSockets.count == socketsBefore + 1)  // reconnected immediately
    }

    /// A path change while the stream is healthy must not churn the socket: a
    /// Wi-Fi↔cellular handoff (`satisfied` throughout) leaves the connection alone.
    ///
    /// The restore edge still backfills — the link *did* drop, so the stream may have
    /// missed events regardless of what the socket believes about itself — but that
    /// is a REST refresh, not a reconnect. The socket is what must stay untouched.
    @Test func pathChange_whileConnected_doesNotChurnSocket() async {
        let h = await startedHarness()
        h.socket?.emit(.connected([:]))
        let socketsBefore = h.provider.createdSockets.count

        h.pathMonitor.emit(satisfied: false)
        h.pathMonitor.emit(satisfied: true)

        #expect(h.provider.createdSockets.count == socketsBefore)
    }

    /// The initial (already-satisfied) callback the live monitor delivers right
    /// after `start()` must not open a second socket racing the startup connect.
    @Test func initialSatisfiedCallback_isNoop() async {
        let h = await startedHarness()
        let socketsBefore = h.provider.createdSockets.count

        h.pathMonitor.emit(satisfied: true)

        #expect(h.provider.createdSockets.count == socketsBefore)
    }

    /// `stop()` cancels path monitoring so a late restore edge cannot resurrect a
    /// torn-down connection.
    @Test func stop_cancelsPathMonitor() async {
        let h = await startedHarness()
        #expect(h.pathMonitor.started == true)

        h.coordinator.stop()

        #expect(h.pathMonitor.cancelled == true)
    }
}
