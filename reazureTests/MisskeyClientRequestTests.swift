//
//  MisskeyClientRequestTests.swift
//  reazureTests
//
//  Regression coverage for the Misskey JSON-body transport seam: auth-in-body,
//  endpoint/path wiring, the favourite ⇔ ⭐ reaction and boost ⇔ renote mappings,
//  the visibility → Misskey value mapping, and the empty (204) body decode path.
//

import Foundation
import Testing

@testable import reazure

struct MisskeyClientRequestTests {

    private func account(token: String = "tok", server: String = "ex.example") -> Account {
        Account(id: "a1", username: "bob", server: .misskey(address: server), accessToken: token)
    }

    private let userJSON = #"{"id":"u1","username":"alice","name":"Alice","host":null,"avatarUrl":"","isBot":false,"isLocked":false}"#

    private func noteJSON(id: String) -> String {
        return """
        {"id":"\(id)","createdAt":"2024-01-01T00:00:00.000Z","text":"hi","cw":null,"visibility":"public","user":\(userJSON),"userId":"u1","replyId":null,"renoteId":null,"reply":null,"renote":null,"files":[],"myReaction":null,"url":null,"uri":null}
        """
    }

    private func createNoteResponse(id: String) -> String {
        return #"{"createdNote":\#(noteJSON(id: id))}"#
    }

    @Test func homeTimeline_postsWithTokenAndLimitInBody() async throws {
        let fake = FakeMisskeyRequestPerformer()
        fake.responseJSON = "[]"
        let client = MisskeyClient(using: account(token: "secret"), performer: fake)

        _ = try await client.homeTimeline(limit: 20)

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/timeline")
        #expect(fake.lastCall?.body["i"] as? String == "secret")
        #expect(fake.lastCall?.body["limit"] as? Int == 20)
    }

    @Test func favourite_createsStarReaction() async throws {
        let fake = FakeMisskeyRequestPerformer()
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.favourite(id: "n1")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/reactions/create")
        #expect(fake.lastCall?.body["noteId"] as? String == "n1")
        #expect(fake.lastCall?.body["reaction"] as? String == "⭐")
    }

    @Test func unfavourite_deletesReaction() async throws {
        let fake = FakeMisskeyRequestPerformer()
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.unfavourite(id: "n1")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/reactions/delete")
        #expect(fake.lastCall?.body["noteId"] as? String == "n1")
    }

    @Test func reblog_createsRenote() async throws {
        let fake = FakeMisskeyRequestPerformer()
        fake.responseJSON = createNoteResponse(id: "renote-1")
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.reblog(id: "n1")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/create")
        #expect(fake.lastCall?.body["renoteId"] as? String == "n1")
    }

    @Test func unreblog_callsUnrenoteWithNoteId() async throws {
        let fake = FakeMisskeyRequestPerformer()
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.unreblog(id: "n1")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/unrenote")
        #expect(fake.lastCall?.body["noteId"] as? String == "n1")
    }

    @Test func post_mapsVisibilityToMisskeyValueAndForwardsReply() async throws {
        let fake = FakeMisskeyRequestPerformer()
        fake.responseJSON = createNoteResponse(id: "new")
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.post(content: "hello", visibility: .unlisted, replyTo: "42")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/create")
        #expect(fake.lastCall?.body["visibility"] as? String == "home")
        #expect(fake.lastCall?.body["text"] as? String == "hello")
        #expect(fake.lastCall?.body["replyId"] as? String == "42")
    }

    @Test func delete_decodesEmptyBodyWithoutThrowing() async throws {
        let fake = FakeMisskeyRequestPerformer()
        fake.responseJSON = ""   // empty body → treated as {} and decoded as EmptyResponse
        let client = MisskeyClient(using: account(), performer: fake)

        try await client.delete(id: "n1")

        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/notes/delete")
        #expect(fake.lastCall?.body["noteId"] as? String == "n1")
    }
}
