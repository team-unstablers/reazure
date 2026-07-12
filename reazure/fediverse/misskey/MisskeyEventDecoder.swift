//
//  MisskeyEventDecoder.swift
//  reazure
//
//  The Misskey end of the `StreamingEventDecoder` seam: decodes a streaming
//  payload (a Note / Notification JSON string, re-packaged by
//  `MisskeyStreamingAdapter`) into the shared adaptors.
//

struct MisskeyEventDecoder: StreamingEventDecoder {
    func decodeStatus(from payload: String) throws -> StatusAdaptor {
        let note = try JSON.parse(payload, to: Misskey.Note.self)
        return MisskeyStatusAdaptor(from: note)
    }

    func decodeNotification(from payload: String) throws -> NotificationAdaptor {
        let notification = try JSON.parse(payload, to: Misskey.Notification.self)
        return MisskeyNotificationAdaptor(from: notification)
    }
}
