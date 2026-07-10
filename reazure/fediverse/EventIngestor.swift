//
//  EventIngestor.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

/// Decode seam for a streaming *payload*: turns a raw event payload string into
/// the fediverse adaptors the models wrap. This abstracts the payload decode
/// only — the streaming *envelope* (`Mastodon.StreamingEvent`) and the
/// `update`/`notification` demux in `EventIngestor` are still Mastodon-shaped, so
/// a real (non-stub) Misskey backend would also need a server-agnostic event
/// abstraction, not just a new decoder. The Mastodon implementation
/// (`MastodonEventDecoder`) lives alongside the other Mastodon adaptors.
protocol StreamingEventDecoder {
    func decodeStatus(from payload: String) throws -> StatusAdaptor
    func decodeNotification(from payload: String) throws -> NotificationAdaptor
}

/// Turns decoded streaming events into timeline mutations.
///
/// Extracted from `SharedClient.ingest` so the streaming decode pipeline
/// (payload → adaptor → model → prepend, plus notification presentation) no
/// longer inlines `Mastodon.Status`/`Mastodon.Notification` parsing into the
/// server-agnostic hub. The concrete decode is injected as a
/// `StreamingEventDecoder`, and the timelines / performer / presenter are
/// injected too, so a Misskey backend can be added without editing this type or
/// `SharedClient`.
///
/// Timelines are supplied as closures because the facade rebuilds them per
/// account; the closures always read the live models. The timeline mutation and
/// notification presentation run on the main thread, matching the prior inline
/// behaviour.
final class EventIngestor {
    private let decoder: StreamingEventDecoder
    private weak var performer: StatusModelActionPerformer?
    private let presenter: NotificationPresenter
    private let homeTimeline: () -> TimelineModel?
    private let notificationTimeline: () -> TimelineModel?
    private let isNotificationTabActive: () -> Bool

    init(decoder: StreamingEventDecoder,
         performer: StatusModelActionPerformer?,
         presenter: NotificationPresenter,
         homeTimeline: @escaping () -> TimelineModel?,
         notificationTimeline: @escaping () -> TimelineModel?,
         isNotificationTabActive: @escaping () -> Bool) {
        self.decoder = decoder
        self.performer = performer
        self.presenter = presenter
        self.homeTimeline = homeTimeline
        self.notificationTimeline = notificationTimeline
        self.isNotificationTabActive = isNotificationTabActive
    }

    /// Decodes and applies a single streaming event.
    func ingest(_ event: Mastodon.StreamingEvent) {
        switch event.event {
        case "update":
            guard let payload = event.payload else {
                print("XXX: Invalid payload")
                return
            }
            do {
                let adaptor = try decoder.decodeStatus(from: payload)

                DispatchQueue.main.async {
                    let model = StatusModel(adaptor: adaptor, performer: self.performer)
                    self.homeTimeline()?.prepend(model)
                }
            } catch {
                print("EventIngestor:ingest: \(error)")
            }
        case "notification":
            guard let payload = event.payload else {
                print("XXX: Invalid payload")
                return
            }
            do {
                let adaptor = try decoder.decodeNotification(from: payload)

                DispatchQueue.main.async {
                    guard let model = NotificationModel(adaptor: adaptor, performer: self.performer) else {
                        return
                    }

                    self.notificationTimeline()?.prepend(model)

                    self.presenter.present(isNotificationTabActive: self.isNotificationTabActive())
                }
            } catch {
                print("EventIngestor:ingest: \(error)")
            }
        default:
            break
        }
    }
}
