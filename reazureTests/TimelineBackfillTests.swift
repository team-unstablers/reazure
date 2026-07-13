//
//  TimelineBackfillTests.swift
//  reazureTests
//
//  Regression coverage for the backfill that runs whenever the stream is reopened
//  (foreground return, restored network path, backoff reconnect).
//
//  This path carries more weight than its size suggests: the app is streaming-only
//  with no offline cache, and streaming delivers only what arrives *after* it
//  connects — it never replays the gap left by a suspend or a dropped socket. The
//  REST refresh here is therefore the sole mechanism by which those missed statuses
//  and notifications are ever recovered.
//
//  The subtlety worth pinning is the unread accounting. "How many entries did this
//  refresh newly insert" is what becomes the notification badge, so it has to mean
//  *newly inserted*, not "size of the fetched page" — otherwise every refresh would
//  re-count the entries already on screen.
//

import Foundation
import Testing

@testable import reazure

@MainActor
struct TimelineBackfillTests {

    // MARK: - helpers

    private func status(_ id: String) -> FakeStatusAdaptor {
        FakeStatusAdaptor(id: id)
    }

    private func notification(_ id: String) -> FakeNotificationAdaptor {
        FakeNotificationAdaptor(id: id, status: FakeStatusAdaptor(id: "status-\(id)"))
    }

    /// Runs `update(completion:)` and awaits its main-thread completion, returning
    /// the recovered count.
    private func recover(_ timeline: TimelineModel) async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            timeline.update { continuation.resume(returning: $0) }
        }
    }

    /// Spins the main queue until `condition` holds, letting the completion's main-hop
    /// land without a real clock.
    private func eventually(iterations: Int = 500, _ condition: () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            await flushMainQueue()
        }
    }

    private func silentPreferences() -> PreferencesManager {
        let prefs = PreferencesManager()
        prefs.playSoundOnNotification = false
        prefs.vibrateOnNotification = false
        return prefs
    }

    // MARK: - TimelineModel: recovered count

    /// The count a backfill reports is what becomes unread, so it must exclude
    /// entries the timeline already held. A refresh that returns the same page it
    /// returned before has recovered *nothing*, even though the page is non-empty.
    @Test func update_countsOnlyEntriesNotAlreadyPresent() async {
        var page = [status("3"), status("2"), status("1")]
        let timeline = TimelineModel(fetchFunction: { _ in
            page.map { StatusModel(adaptor: $0, performer: nil) }
        })

        let first = await recover(timeline)
        #expect(first == 3)                    // initial fill: all three are new

        let unchanged = await recover(timeline)
        #expect(unchanged == 0)                // same page again: nothing recovered
        #expect(timeline.statuses.count == 3)  // and nothing duplicated

        page = [status("5"), status("4"), status("3"), status("2"), status("1")]
        let recovered = await recover(timeline)
        #expect(recovered == 2)                // only "5" and "4" are actually new
        #expect(timeline.statuses.count == 5)
    }

    /// A backfill is commonly triggered from two sources at once — a foreground
    /// return and a restored network path land together — so overlapping refreshes
    /// must collapse instead of firing redundant requests.
    @Test func update_whileFetchInFlight_isSkipped() async {
        var fetchCount = 0
        let gate = AsyncGate()

        let timeline = TimelineModel(fetchFunction: { _ in
            fetchCount += 1
            await gate.wait()
            return [StatusModel(adaptor: FakeStatusAdaptor(id: "1"), performer: nil)]
        })

        var firstResult: Int?
        var secondResult: Int?
        timeline.update { firstResult = $0 }
        timeline.update { secondResult = $0 }   // lands while the first is still in flight

        #expect(secondResult == 0)              // skipped, and reported as "recovered nothing"

        await gate.open()
        await eventually { firstResult != nil }

        #expect(fetchCount == 1)                // the duplicate never hit the network
        #expect(firstResult == 1)
    }

    /// A failed refresh must report zero rather than leaving the caller hanging, and
    /// must clear the in-flight guard so the next attempt can run.
    @Test func update_whenFetchFails_reportsZeroAndClearsGuard() async {
        struct Boom: Error {}
        var shouldFail = true

        let timeline = TimelineModel(fetchFunction: { _ in
            if shouldFail { throw Boom() }
            return [StatusModel(adaptor: FakeStatusAdaptor(id: "1"), performer: nil)]
        })

        let failed = await recover(timeline)
        #expect(failed == 0)

        shouldFail = false
        let retried = await recover(timeline)
        #expect(retried == 1)   // guard released — the retry was not swallowed
    }

    // MARK: - NotificationPresenter: batch feedback

    /// Unread accrues per recovered notification, but the alert fires once for the
    /// batch. Reusing the single-notification path here would machine-gun the sound
    /// on every foreground return.
    @Test func presentBackfill_accruesEachUnreadButAlertsOnce() {
        var unread = 0
        var sounds = 0
        let prefs = silentPreferences()
        prefs.playSoundOnNotification = true

        let presenter = NotificationPresenter(
            preferences: prefs,
            effects: NotificationPresenter.Effects(playSound: { _ in sounds += 1 }, vibrate: {}),
            incrementUnread: { unread += $0 }
        )

        presenter.presentBackfill(count: 7, isNotificationTabActive: false)

        #expect(unread == 7)
        #expect(sounds == 1)
    }

    /// A refresh that recovered nothing is not an event: no badge, no sound.
    @Test func presentBackfill_withNothingRecovered_isSilent() {
        var unread = 0
        var sounds = 0
        let prefs = silentPreferences()
        prefs.playSoundOnNotification = true

        let presenter = NotificationPresenter(
            preferences: prefs,
            effects: NotificationPresenter.Effects(playSound: { _ in sounds += 1 }, vibrate: {}),
            incrementUnread: { unread += $0 }
        )

        presenter.presentBackfill(count: 0, isNotificationTabActive: false)

        #expect(unread == 0)
        #expect(sounds == 0)
    }

    /// Matches the streaming path: nothing accrues while the user is looking at the
    /// notifications tab.
    @Test func presentBackfill_whileViewingNotifications_accruesNoUnread() {
        var unread = 0
        let presenter = NotificationPresenter(
            preferences: silentPreferences(),
            effects: NotificationPresenter.Effects(playSound: { _ in }, vibrate: {}),
            incrementUnread: { unread += $0 }
        )

        presenter.presentBackfill(count: 4, isNotificationTabActive: true)

        #expect(unread == 0)
    }

    // MARK: - SharedClient.backfillTimelines

    private func makeHub() -> SharedClient {
        SharedClient(
            socketProvider: FakeWebSocketProvider(),
            scheduler: ManualReconnectScheduler(),
            configurationProvider: { _ in .fixture() },
            pathMonitorFactory: { FakePathMonitor() }
        )
    }

    /// The notifications tab fetches on `onAppear`, so a user who has only ever
    /// looked at the home timeline leaves it empty. Backfilling then returns the
    /// account's existing notification *history* — which was never "missed" and must
    /// not land as unread. Getting this wrong would badge a fresh launch with a full
    /// page of old notifications.
    @Test func backfillTimelines_onFirstFill_accruesNoUnread() async {
        let hub = makeHub()
        hub.use(account: .fixture())

        hub.timeline[.home]?.fetchFunction = { _ in [] }
        hub.timeline[.notifications]?.fetchFunction = { _ in
            [self.notification("3"), self.notification("2"), self.notification("1")]
                .compactMap { NotificationModel(adaptor: $0, performer: nil) }
        }

        hub.backfillTimelines()
        await flushMainQueue()

        #expect(hub.timeline[.notifications]?.statuses.count == 3)  // history did load
        #expect(hub.unreadNotificationCount == 0)                   // but nothing was "missed"

        withExtendedLifetime(hub) {}
    }

    /// Once the timeline has been seeded, a later backfill *is* a recovery: whatever
    /// it newly pulls in arrived while the stream was down, and badges accordingly.
    @Test func backfillTimelines_afterSeeding_accruesRecoveredAsUnread() async {
        let hub = makeHub()
        hub.use(account: .fixture())

        var page = [notification("1")]
        hub.timeline[.home]?.fetchFunction = { _ in [] }
        hub.timeline[.notifications]?.fetchFunction = { _ in
            page.compactMap { NotificationModel(adaptor: $0, performer: nil) }
        }

        // First fill (as the notifications tab's onAppear would do) — no unread.
        hub.backfillTimelines()
        await flushMainQueue()
        #expect(hub.unreadNotificationCount == 0)

        // Two notifications arrive while the app is suspended; the stream missed both.
        page = [notification("3"), notification("2"), notification("1")]

        hub.backfillTimelines()
        await flushMainQueue()

        #expect(hub.unreadNotificationCount == 2)                   // only the two new ones
        #expect(hub.timeline[.notifications]?.statuses.count == 3)

        withExtendedLifetime(hub) {}
    }
}

/// A one-shot gate letting a test hold a fetch open, so a second `update()` can be
/// observed landing while the first is still in flight.
private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false

    func wait() async {
        if opened { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            self.continuation = c
        }
    }

    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
