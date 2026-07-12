//
//  MisskeyEventDecoderTests.swift
//  reazureTests
//
//  Pins the Misskey end of the `StreamingEventDecoder` seam: Note / Notification
//  decoding into the shared adaptors, the favourite ⇔ reaction / boost ⇔ renote
//  mappings, and the content escaping.
//

import Foundation
import Testing

@testable import reazure

struct MisskeyEventDecoderTests {

    private let userJSON = #"{"id":"u1","username":"alice","name":"Alice","host":null,"avatarUrl":"https://x/a.png","isBot":false,"isLocked":false}"#

    private func noteJSON(id: String = "n1",
                          text: String? = "hello",
                          myReaction: String? = nil,
                          renoteId: String? = nil,
                          renote: String? = nil) -> String {
        let textField = text.map { "\"\($0)\"" } ?? "null"
        let myReactionField = myReaction.map { "\"\($0)\"" } ?? "null"
        let renoteIdField = renoteId.map { "\"\($0)\"" } ?? "null"
        let renoteField = renote ?? "null"
        return """
        {"id":"\(id)","createdAt":"2024-01-01T00:00:00.000Z","text":\(textField),"cw":null,"visibility":"public","user":\(userJSON),"userId":"u1","replyId":null,"renoteId":\(renoteIdField),"reply":null,"renote":\(renoteField),"files":[],"myReaction":\(myReactionField),"url":null,"uri":null}
        """
    }

    private func notificationJSON(type: String, note: String?) -> String {
        let noteField = note ?? "null"
        return """
        {"id":"noti1","createdAt":"2024-01-01T00:00:00.000Z","type":"\(type)","user":\(userJSON),"userId":"u1","note":\(noteField),"reaction":null}
        """
    }

    @Test func decodeStatus_parsesNote() throws {
        let adaptor = try MisskeyEventDecoder().decodeStatus(from: noteJSON(id: "n1", text: "hello"))

        #expect(adaptor.id == "n1")
        #expect(adaptor.content == "hello")
        #expect(adaptor.favourited == false)
    }

    @Test func decodeStatus_favouritedWhenMyReactionPresent() throws {
        let adaptor = try MisskeyEventDecoder().decodeStatus(from: noteJSON(text: "hi", myReaction: "⭐"))

        #expect(adaptor.favourited == true)
    }

    @Test func decodeStatus_escapesHTMLAndConvertsNewlines() throws {
        // `\\n` in the source becomes a JSON `\n`, decoded to a real newline.
        let json = noteJSON(text: "a<b>\\nc")
        let adaptor = try MisskeyEventDecoder().decodeStatus(from: json)

        #expect(adaptor.content.contains("&lt;b&gt;"))
        #expect(adaptor.content.contains("<br>"))
        #expect(!adaptor.content.contains("<b>"))
    }

    @Test func decodeStatus_pureRenoteMapsToReblog() throws {
        let inner = noteJSON(id: "orig", text: "original")
        let renote = noteJSON(id: "n2", text: nil, renoteId: "orig", renote: inner)

        let adaptor = try MisskeyEventDecoder().decodeStatus(from: renote)

        #expect(adaptor.reblog?.id == "orig")
    }

    @Test func decodeNotification_reactionMapsToFavourite() throws {
        let json = notificationJSON(type: "reaction", note: noteJSON(id: "n1"))
        let adaptor = try MisskeyEventDecoder().decodeNotification(from: json)

        #expect(adaptor.type == .favourite)
        #expect(adaptor.status?.id == "n1")
    }

    @Test func decodeNotification_renoteMapsToReblog() throws {
        let json = notificationJSON(type: "renote", note: noteJSON(id: "n3"))
        let adaptor = try MisskeyEventDecoder().decodeNotification(from: json)

        #expect(adaptor.type == .reblog)
    }

    @Test func decodeNotification_followHasNoStatus() throws {
        // Follow notifications carry no note; `NotificationModel` later drops them,
        // matching Mastodon's follow-notification behaviour.
        let json = notificationJSON(type: "follow", note: nil)
        let adaptor = try MisskeyEventDecoder().decodeNotification(from: json)

        #expect(adaptor.type == .follow)
        #expect(adaptor.status == nil)
    }

    @Test func decodeStatus_onMalformedPayload_throws() {
        #expect(throws: (any Error).self) {
            try MisskeyEventDecoder().decodeStatus(from: "not json")
        }
    }
}
