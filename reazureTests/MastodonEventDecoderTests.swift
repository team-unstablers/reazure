//
//  MastodonEventDecoderTests.swift
//  reazureTests
//
//  Pins the Mastodon end of the `StreamingEventDecoder` seam (roadmap step 4.1):
//  the `Mastodon.Status`/`Mastodon.Notification` parsing that used to be inlined
//  in `SharedClient` now lives in `MastodonEventDecoder`.
//

import Foundation
import Testing

@testable import reazure

struct MastodonEventDecoderTests {

    private let account = """
    {"id":"a1","username":"bob","acct":"bob@example.com","url":null,"display_name":"Bob","avatar":"","emojis":[]}
    """

    private func statusJSON(id: String = "123", content: String = "hello") -> String {
        """
        {"id":"\(id)","created_at":"2024-01-01T00:00:00.000Z","in_reply_to_id":null,"url":null,"visibility":"public","content":"\(content)","account":\(account),"favourited":false,"reblogged":false,"reblog":null,"emojis":[],"mentions":[],"media_attachments":[],"application":null}
        """
    }

    @Test func decodeStatus_parsesIntoAdaptor() throws {
        let adaptor = try MastodonEventDecoder().decodeStatus(from: statusJSON(id: "123", content: "hello"))

        #expect(adaptor.id == "123")
        #expect(adaptor.content == "hello")
        #expect(adaptor.favourited == false)
    }

    @Test func decodeNotification_parsesNestedStatus() throws {
        let json = """
        {"id":"n1","type":"mention","created_at":"2024-01-01T00:00:00.000Z","account":\(account),"status":\(statusJSON(id: "555"))}
        """

        let adaptor = try MastodonEventDecoder().decodeNotification(from: json)

        #expect(adaptor.id == "n1")
        #expect(adaptor.type == .mention)
        #expect(adaptor.status?.id == "555")
    }

    @Test func decodeStatus_onMalformedPayload_throws() {
        #expect(throws: (any Error).self) {
            try MastodonEventDecoder().decodeStatus(from: "not json")
        }
    }
}
