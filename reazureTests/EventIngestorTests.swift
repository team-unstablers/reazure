//
//  EventIngestorTests.swift
//  reazureTests
//
//  Regression coverage for `EventIngestor` (roadmap step 4.1). The streaming
//  decode pipeline (payload → adaptor → model → prepend, plus notification
//  presentation) was extracted out of `SharedClient` behind a
//  `StreamingEventDecoder` seam. These pin the ingest behaviour with a fake
//  decoder — no Mastodon JSON, no network — and a separate suite pins the real
//  `MastodonEventDecoder`.
//

import Foundation
import Testing

@testable import reazure

@MainActor
struct EventIngestorTests {

    private func silentPreferences() -> PreferencesManager {
        let prefs = PreferencesManager()
        prefs.playSoundOnNotification = false
        prefs.vibrateOnNotification = false
        return prefs
    }

    /// Builds an ingestor over two fresh timelines with the given decoder. The
    /// presenter's unread increments are recorded via `unread`.
    private func makeIngestor(
        decoder: StreamingEventDecoder,
        home: TimelineModel,
        notifications: TimelineModel,
        isNotificationTabActive: Bool = false,
        unread: @escaping () -> Void = {}
    ) -> EventIngestor {
        let presenter = NotificationPresenter(
            preferences: silentPreferences(),
            effects: NotificationPresenter.Effects(playSound: { _ in }, vibrate: {}),
            incrementUnread: unread
        )
        return EventIngestor(
            decoder: decoder,
            performer: nil,
            presenter: presenter,
            homeTimeline: { home },
            notificationTimeline: { notifications },
            isNotificationTabActive: { isNotificationTabActive }
        )
    }

    private func event(_ type: String, payload: String? = "{}") -> Mastodon.StreamingEvent {
        Mastodon.StreamingEvent(event: type, payload: payload)
    }

    // MARK: - update

    @Test func updateEvent_prependsDecodedStatusToHome() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        let decoder = FakeStreamingEventDecoder(status: FakeStatusAdaptor(id: "s-1"))
        let ingestor = makeIngestor(decoder: decoder, home: home, notifications: notifications)

        ingestor.ingest(event("update"))
        await flushMainQueue()

        #expect(home.statuses.count == 1)
        #expect(home.statuses.first?.id == "s-1")
        #expect(notifications.statuses.isEmpty)
    }

    @Test func updateEvent_withNilPayload_isDropped() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        let ingestor = makeIngestor(decoder: FakeStreamingEventDecoder(), home: home, notifications: notifications)

        ingestor.ingest(event("update", payload: nil))
        await flushMainQueue()

        #expect(home.statuses.isEmpty)
    }

    @Test func updateEvent_whenDecoderThrows_isSwallowed() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        let decoder = FakeStreamingEventDecoder(error: FakePerformerError.noResolveResult)
        let ingestor = makeIngestor(decoder: decoder, home: home, notifications: notifications)

        ingestor.ingest(event("update"))
        await flushMainQueue()

        #expect(home.statuses.isEmpty)
    }

    // MARK: - notification

    @Test func notificationEvent_prependsModelAndPresents() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        var unread = 0
        let adaptor = FakeNotificationAdaptor(id: "n-1", status: FakeStatusAdaptor(id: "s-9"))
        let decoder = FakeStreamingEventDecoder(notification: adaptor)
        let ingestor = makeIngestor(
            decoder: decoder, home: home, notifications: notifications,
            isNotificationTabActive: false, unread: { unread += 1 }
        )

        ingestor.ingest(event("notification"))
        await flushMainQueue()

        #expect(notifications.statuses.count == 1)
        #expect(unread == 1)         // presenter ran, tab inactive → unread accrued
        #expect(home.statuses.isEmpty)
    }

    /// A notification with no underlying status (e.g. a follow) makes
    /// `NotificationModel.init?` fail; nothing is prepended and — because the
    /// guard returns before it — the presenter is not run.
    @Test func notificationEvent_withoutStatus_isDroppedAndDoesNotPresent() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        var unread = 0
        let adaptor = FakeNotificationAdaptor(id: "n-2", type: .follow, status: nil)
        let decoder = FakeStreamingEventDecoder(notification: adaptor)
        let ingestor = makeIngestor(
            decoder: decoder, home: home, notifications: notifications, unread: { unread += 1 }
        )

        ingestor.ingest(event("notification"))
        await flushMainQueue()

        #expect(notifications.statuses.isEmpty)
        #expect(unread == 0)
    }

    @Test func notificationEvent_whileViewingNotifications_doesNotAccrueUnread() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        var unread = 0
        let adaptor = FakeNotificationAdaptor(id: "n-3", status: FakeStatusAdaptor(id: "s-3"))
        let decoder = FakeStreamingEventDecoder(notification: adaptor)
        let ingestor = makeIngestor(
            decoder: decoder, home: home, notifications: notifications,
            isNotificationTabActive: true, unread: { unread += 1 }
        )

        ingestor.ingest(event("notification"))
        await flushMainQueue()

        #expect(notifications.statuses.count == 1)
        #expect(unread == 0)
    }

    // MARK: - unknown

    @Test func unknownEvent_isIgnored() async {
        let home = TimelineModel()
        let notifications = TimelineModel()
        let ingestor = makeIngestor(decoder: FakeStreamingEventDecoder(), home: home, notifications: notifications)

        ingestor.ingest(event("filters_changed"))
        await flushMainQueue()

        #expect(home.statuses.isEmpty)
        #expect(notifications.statuses.isEmpty)
    }
}
