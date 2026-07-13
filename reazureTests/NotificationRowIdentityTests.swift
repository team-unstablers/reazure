//
//  NotificationRowIdentityTests.swift
//  reazureTests
//
//  Regression coverage for notification row identity and ordering.
//
//  `NotificationModel` inherits `StatusModel`, whose identity used to be the
//  wrapped status' id. Two consequences, both user-visible:
//
//   1. Several people favouriting/boosting one post produced several
//      notifications that the timeline's `OrderedSet` collapsed into a single
//      row (and, for streaming, silently dropped on `insert`).
//   2. `update()` sorted by that same id, so notifications were ordered by the
//      *post* they referred to rather than by when the event happened.
//
//  A notification row is now identified and ordered by the notification itself.
//

import Foundation
import Testing

@testable import reazure

@MainActor
struct NotificationRowIdentityTests {

    private func notification(
        id: String,
        createdAt: String,
        type: NotificationType = .favourite,
        statusId: String,
        statusCreatedAt: String = "2024-01-01T00:00:00.000Z"
    ) -> NotificationModel {
        let adaptor = FakeNotificationAdaptor(
            id: id,
            type: type,
            createdAt: createdAt,
            account: FakeAccountAdaptor(),
            status: FakeStatusAdaptor(id: statusId, createdAt: statusCreatedAt)
        )

        return NotificationModel(adaptor: adaptor)!
    }

    /// `update()` hops through a `Task` and then a `DispatchQueue.main.async`, so
    /// a single main-queue round-trip is not enough to observe the merge. The
    /// insert and the sort share one main-queue block, so a settled row count
    /// means the ordering has settled too.
    private func waitForRows(_ timeline: TimelineModel, count: Int) async {
        for _ in 0..<200 {
            if timeline.statuses.count >= count {
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - identity

    @Test func notificationModel_isIdentifiedByNotificationId() {
        let model = notification(id: "n-1", createdAt: "2024-06-01T00:00:00.000Z", statusId: "s-1")

        #expect(model.id == "n-1")
        #expect(model.status.id == "s-1")   // the wrapped status is untouched
    }

    @Test func statusModel_isStillIdentifiedByStatusId() {
        let model = StatusModel(adaptor: FakeStatusAdaptor(id: "s-1"))

        #expect(model.id == "s-1")
    }

    /// The collapse regression: two people favourite the same post.
    @Test func distinctNotificationsOnSamePost_stayDistinctRows() {
        let timeline = TimelineModel()

        timeline.prepend(notification(id: "n-1", createdAt: "2024-06-01T00:00:00.000Z", statusId: "s-1"))
        timeline.prepend(notification(id: "n-2", createdAt: "2024-06-02T00:00:00.000Z", statusId: "s-1"))

        #expect(timeline.statuses.count == 2)
        #expect(timeline.statuses.map(\.id) == ["n-2", "n-1"])
    }

    /// Deduplication still works — it is now keyed on the notification, so the
    /// same notification arriving over streaming and again over a REST backfill
    /// yields one row.
    @Test func sameNotificationDeliveredTwice_isDeduplicated() {
        let timeline = TimelineModel()

        timeline.prepend(notification(id: "n-1", createdAt: "2024-06-01T00:00:00.000Z", statusId: "s-1"))
        timeline.prepend(notification(id: "n-1", createdAt: "2024-06-01T00:00:00.000Z", statusId: "s-1"))

        #expect(timeline.statuses.count == 1)
    }

    // MARK: - ordering

    /// The ordering regression: a *recent* notification about an *old* post must
    /// still sort above an older notification about a newer post. Sorting by the
    /// status id put them the other way round.
    @Test func update_ordersByEventTime_notByPost() async {
        // Newest notification (n-200), but about the oldest post (s-111).
        let recent = notification(
            id: "n-200", createdAt: "2024-06-02T00:00:00.000Z",
            statusId: "s-111", statusCreatedAt: "2024-01-01T00:00:00.000Z"
        )
        // Older notification (n-100), about the newest post (s-999).
        let older = notification(
            id: "n-100", createdAt: "2024-06-01T00:00:00.000Z",
            statusId: "s-999", statusCreatedAt: "2024-05-31T00:00:00.000Z"
        )

        let timeline = TimelineModel { _ in [recent, older] }
        timeline.update()
        await waitForRows(timeline, count: 2)

        #expect(timeline.statuses.map(\.id) == ["n-200", "n-100"])
    }

    @Test func update_ordersStatusesByPostTime() async {
        let newer = StatusModel(adaptor: FakeStatusAdaptor(id: "s-2", createdAt: "2024-06-02T00:00:00.000Z"))
        let older = StatusModel(adaptor: FakeStatusAdaptor(id: "s-1", createdAt: "2024-06-01T00:00:00.000Z"))

        let timeline = TimelineModel { _ in [newer, older] }
        timeline.update()
        await waitForRows(timeline, count: 2)

        #expect(timeline.statuses.map(\.id) == ["s-2", "s-1"])
    }
}

struct TimelineSortKeyTests {

    @Test func ordersByEventTime() {
        let older = TimelineSortKey(createdAt: "2024-06-01T00:00:00.000Z", id: "b")
        let newer = TimelineSortKey(createdAt: "2024-06-02T00:00:00.000Z", id: "a")

        #expect(older < newer)   // the time wins over the id
    }

    @Test func tieBreaksById() {
        let a = TimelineSortKey(createdAt: "2024-06-01T00:00:00.000Z", id: "a")
        let b = TimelineSortKey(createdAt: "2024-06-01T00:00:00.000Z", id: "b")

        #expect(a < b)
    }

    /// Why the id string is not the sort key: a Mastodon notification id is a
    /// plain auto-increment integer on some instances, and `"1000" < "999"`
    /// lexicographically.
    @Test func digitCountGrowth_doesNotFlipOrder() {
        let id999 = TimelineSortKey(createdAt: "2024-06-01T00:00:00.000Z", id: "999")
        let id1000 = TimelineSortKey(createdAt: "2024-06-02T00:00:00.000Z", id: "1000")

        #expect(id999 < id1000)
        #expect("1000" < "999")   // ...which is what the old comparison did
    }

    @Test func parsesTimestampsWithoutFractionalSeconds() {
        let older = TimelineSortKey(createdAt: "2024-06-01T00:00:00Z", id: "a")
        let newer = TimelineSortKey(createdAt: "2024-06-02T00:00:00Z", id: "a")

        #expect(older < newer)
        #expect(older.date != .distantPast)   // it parsed, rather than falling back
    }

    @Test func unparsableTimestamp_sortsOldest() {
        let broken = TimelineSortKey(createdAt: "not a date", id: "z")
        let parsed = TimelineSortKey(createdAt: "2024-06-01T00:00:00.000Z", id: "a")

        #expect(broken < parsed)
        #expect(broken.date == .distantPast)
    }
}
