//
//  MisskeyStreamingAdapterTests.swift
//  reazureTests
//
//  Covers the Misskey streaming strategy: the wss URL, the on-connect channel
//  subscriptions, and the channel-frame → shared-envelope translation.
//

import Foundation
import Testing

@testable import reazure

struct MisskeyStreamingAdapterTests {

    private let adapter = MisskeyStreamingAdapter()

    @Test func translate_noteFrameBecomesUpdateEvent() {
        let frame = #"{"type":"channel","body":{"id":"ch1","type":"note","body":{"id":"n1","text":"hi"}}}"#
        let event = adapter.translate(text: frame)

        #expect(event?.event == "update")
        #expect(event?.payload?.contains("n1") == true)
    }

    @Test func translate_notificationFrameBecomesNotificationEvent() {
        let frame = #"{"type":"channel","body":{"id":"ch2","type":"notification","body":{"id":"noti1","type":"reaction"}}}"#
        let event = adapter.translate(text: frame)

        #expect(event?.event == "notification")
        #expect(event?.payload?.contains("noti1") == true)
    }

    @Test func translate_unknownInnerTypeReturnsNil() {
        let frame = #"{"type":"channel","body":{"id":"ch3","type":"other","body":{}}}"#
        #expect(adapter.translate(text: frame) == nil)
    }

    @Test func translate_nonChannelFrameReturnsNil() {
        #expect(adapter.translate(text: #"{"type":"connected","body":{}}"#) == nil)
    }

    @Test func translate_malformedJSONReturnsNil() {
        #expect(adapter.translate(text: "not json") == nil)
    }

    @Test func onConnected_subscribesToHomeAndMainChannels() {
        var sent: [String] = []
        adapter.onConnected(send: { sent.append($0) })

        #expect(sent.count == 2)
        #expect(sent.allSatisfy { $0.contains("\"type\":\"connect\"") })
        #expect(sent.contains { $0.contains("homeTimeline") })
        #expect(sent.contains { $0.contains("main") })
    }

    @Test func url_buildsMisskeyStreamingURL() {
        let account = Account(id: "a1", username: "bob", server: .misskey(address: "misskey.example"), accessToken: "tok")
        let config = FediverseServerConfiguration(streamingEndpoint: "misskey.example", maxPostLength: 3000)

        let url = adapter.url(account: account, configuration: config)

        #expect(url.absoluteString == "wss://misskey.example/streaming?i=tok")
    }
}
