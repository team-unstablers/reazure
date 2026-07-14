//
//  MastodonClientRequestTests.swift
//  reazureTests
//
//  Regression coverage for the `RequestPerforming` transport seam and the
//  `deleteStatus` decoding fix (roadmap step 4.3). Injecting a fake performer
//  exercises the REST paths — endpoint / method / auth wiring and the decode
//  step that the `String.self` bug used to break — without a network.
//

import Foundation
import Testing

@testable import reazure

struct MastodonClientRequestTests {

    private func account(token: String = "tok", server: String = "ex.example") -> Account {
        Account(id: "a1", username: "bob", server: .mastodon(address: server), accessToken: token)
    }

    private func statusJSON(id: String) -> String {
        let acct = #"{"id":"a1","username":"bob","acct":"bob@example.com","url":null,"display_name":"Bob","avatar":"","emojis":[]}"#
        return """
        {"id":"\(id)","created_at":"2024-01-01T00:00:00.000Z","in_reply_to_id":null,"url":null,"visibility":"public","content":"hi","account":\(acct),"favourited":false,"reblogged":false,"reblog":null,"emojis":[],"mentions":[],"media_attachments":[],"application":null}
        """
    }

    // MARK: - deleteStatus fix

    /// The historical bug decoded the DELETE response as `String`, so every
    /// successful delete threw. It now decodes the returned status object; given a
    /// status body the call must succeed and issue a DELETE to the status endpoint.
    @Test func deleteStatus_succeedsDecodingReturnedStatusObject() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = statusJSON(id: "123")
        let client = MastodonClient(using: account(), performer: fake)

        try await client.deleteStatus(statusId: "123")

        #expect(fake.lastCall?.method == "DELETE")
        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/v1/statuses/123")
    }

    // MARK: - seam wiring

    @Test func favourite_postsToEndpointWithBearerAuth() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = statusJSON(id: "s1")
        let client = MastodonClient(using: account(token: "secret"), performer: fake)

        _ = try await client.favourite(statusId: "s1")

        #expect(fake.lastCall?.method == "POST")
        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/v1/statuses/s1/favourite")
        #expect(fake.lastCall?.headers["Authorization"] == "Bearer secret")
    }

    @Test func postStatus_forwardsContentAndVisibilityParameters() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = statusJSON(id: "new")
        let client = MastodonClient(using: account(), performer: fake)

        _ = try await client.postStatus("hello", visibility: .unlisted, replyTo: "42")

        let call = fake.lastCall
        #expect(call?.method == "POST")
        #expect(call?.parameters["status"] == "hello")
        #expect(call?.parameters["visibility"] == "unlisted")
        #expect(call?.parameters["in_reply_to_id"] == "42")
    }

    // MARK: - moderation

    @Test func block_postsToTheAccountBlockEndpoint() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = #"{"id":"acc-1"}"#
        let client = MastodonClient(using: account(), performer: fake)

        try await client.block(accountId: "acc-1")

        #expect(fake.lastCall?.method == "POST")
        #expect(fake.lastCall?.url.absoluteString == "https://ex.example/api/v1/accounts/acc-1/block")
    }

    /// The reported status rides along as the Rails-style `status_ids[]` array
    /// parameter — plain `status_ids` would be dropped by the server.
    @Test func report_forwardsAccountStatusCategoryAndForwardFlag() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = #"{"id":"report-1"}"#
        let client = MastodonClient(using: account(), performer: fake)

        try await client.report(ReportRequest(
            accountId: "acc-1",
            statusId: "s1",
            statusUrl: "https://other.example/@villain/s1",
            comment: "spam",
            category: .spam,
            forward: true
        ))

        let call = fake.lastCall
        #expect(call?.method == "POST")
        #expect(call?.url.absoluteString == "https://ex.example/api/v1/reports")
        #expect(call?.parameters["account_id"] == "acc-1")
        #expect(call?.parameters["status_ids[]"] == "s1")
        #expect(call?.parameters["comment"] == "spam")
        #expect(call?.parameters["category"] == "spam")
        #expect(call?.parameters["forward"] == "true")
    }

    /// A comment is optional on Mastodon; an empty one must be left out entirely
    /// rather than sent as an empty string.
    @Test func report_withoutComment_omitsTheParameter() async throws {
        let fake = FakeRequestPerformer()
        fake.responseJSON = #"{"id":"report-1"}"#
        let client = MastodonClient(using: account(), performer: fake)

        try await client.report(ReportRequest(accountId: "acc-1", category: .other))

        #expect(fake.lastCall?.parameters["comment"] == nil)
        #expect(fake.lastCall?.parameters["status_ids[]"] == nil)
        #expect(fake.lastCall?.parameters["forward"] == "false")
    }

    /// A decode mismatch surfaces as a thrown error rather than a trap — the class
    /// of failure the `deleteStatus` bug fell into.
    @Test func request_onDecodeMismatch_throwsRatherThanCrashing() async {
        let fake = FakeRequestPerformer()
        fake.responseJSON = "\"not a status object\""   // a JSON string, not a Status
        let client = MastodonClient(using: account(), performer: fake)

        await #expect(throws: (any Error).self) {
            _ = try await client.status(of: "1")
        }
    }
}
