//
//  TestDoubles.swift
//  reazureTests
//
//  Test doubles and helpers shared across the regression suite seeded for the
//  SharedClient decomposition refactor (roadmap step 1.1).
//

import Foundation

@testable import reazure

// MARK: - AccountAdaptor

/// Minimal `AccountAdaptor` stand-in for building `StatusAdaptor` fixtures.
final class FakeAccountAdaptor: AccountAdaptor {
    var id: String
    var username: String
    var acct: String
    var url: String?
    var displayName: String
    var locked: Bool
    var bot: Bool
    var avatar: String
    var emojis: [EmojiAdaptor]

    init(
        id: String = "account-1",
        username: String = "tester",
        acct: String = "tester@example.com",
        url: String? = nil,
        displayName: String = "Tester",
        locked: Bool = false,
        bot: Bool = false,
        avatar: String = "",
        emojis: [EmojiAdaptor] = []
    ) {
        self.id = id
        self.username = username
        self.acct = acct
        self.url = url
        self.displayName = displayName
        self.locked = locked
        self.bot = bot
        self.avatar = avatar
        self.emojis = emojis
    }
}

// MARK: - StatusAdaptor

/// A pure in-memory `StatusAdaptor` with no networking or parsing dependencies.
///
/// The flag properties (`favourited`/`reblogged`/`deleted`) are stored so tests
/// can assert that the optimistic masking flow never mutates the underlying
/// adaptor — it should overlay a `MaskedStatusAdaptor` instead.
final class FakeStatusAdaptor: StatusAdaptor {
    var id: String
    var createdAt: String
    var replyToId: String?
    var url: String?
    var visibility: StatusVisibility
    var content: String
    var parsedContent: HTMLElement
    var spoilerText: String?
    var sensitive: Bool
    var account: AccountAdaptor
    var favourited: Bool
    var reblogged: Bool
    var deleted: Bool
    var reblog: (any StatusAdaptor)?
    var emojis: [EmojiAdaptor]
    var mentions: [MentionAdaptor]
    var attachments: [AttachmentAdaptor]
    var application: ApplicationAdaptor?

    init(
        id: String = "status-1",
        createdAt: String = "2024-01-01T00:00:00.000Z",
        replyToId: String? = nil,
        url: String? = nil,
        visibility: StatusVisibility = .publicType,
        content: String = "",
        spoilerText: String? = nil,
        sensitive: Bool = false,
        account: AccountAdaptor? = nil,
        favourited: Bool = false,
        reblogged: Bool = false,
        deleted: Bool = false,
        reblog: (any StatusAdaptor)? = nil,
        emojis: [EmojiAdaptor] = [],
        mentions: [MentionAdaptor] = [],
        attachments: [AttachmentAdaptor] = [],
        application: ApplicationAdaptor? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.replyToId = replyToId
        self.url = url
        self.visibility = visibility
        self.content = content
        self.parsedContent = HTMLElement(name: "__ROOT__")
        self.spoilerText = spoilerText
        self.sensitive = sensitive
        self.account = account ?? FakeAccountAdaptor()
        self.favourited = favourited
        self.reblogged = reblogged
        self.deleted = deleted
        self.reblog = reblog
        self.emojis = emojis
        self.mentions = mentions
        self.attachments = attachments
        self.application = application
    }
}

// MARK: - NotificationAdaptor

/// In-memory `NotificationAdaptor`. `status == nil` models the
/// not-yet-supported notification types that `NotificationModel.init?` drops.
final class FakeNotificationAdaptor: NotificationAdaptor {
    var id: String
    var type: NotificationType
    var createdAt: String
    var account: AccountAdaptor?
    var status: (any StatusAdaptor)?

    init(
        id: String = "notif-1",
        type: NotificationType = .mention,
        createdAt: String = "2024-01-01T00:00:00.000Z",
        account: AccountAdaptor? = nil,
        status: (any StatusAdaptor)? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.account = account
        self.status = status
    }
}

// MARK: - StreamingEventDecoder

/// A `StreamingEventDecoder` that returns preset adaptors (or throws), so
/// `EventIngestor` can be exercised without real Mastodon JSON.
struct FakeStreamingEventDecoder: StreamingEventDecoder {
    var status: (any StatusAdaptor)?
    var notification: (any NotificationAdaptor)?
    var error: Error?

    func decodeStatus(from payload: String) throws -> StatusAdaptor {
        if let error { throw error }
        return status ?? FakeStatusAdaptor()
    }

    func decodeNotification(from payload: String) throws -> NotificationAdaptor {
        if let error { throw error }
        return notification ?? FakeNotificationAdaptor()
    }
}

// MARK: - RequestPerforming

/// Records each REST call `MastodonClient` routes through the transport seam and
/// decodes a canned JSON body into the requested type — so the decode path (and
/// the historical `deleteStatus` `String.self` bug) is exercised without a
/// network. Conforms without importing Alamofire (the seam is Foundation-only).
final class FakeRequestPerformer: RequestPerforming {
    struct Call {
        let url: URL
        let method: String
        let parameters: [String: String]
        let headers: [String: String]
    }

    private(set) var calls: [Call] = []
    var lastCall: Call? { calls.last }

    /// JSON body decoded into the requested type on each call.
    var responseJSON: String?
    /// When set, thrown after recording the call.
    var error: Error?

    func perform<Response: Decodable & Sendable>(
        url: URL,
        method: String,
        parameters: [String: String],
        headers: [String: String],
        expecting type: Response.Type
    ) async throws -> Response {
        calls.append(Call(url: url, method: method, parameters: parameters, headers: headers))
        if let error { throw error }
        let data = (responseJSON ?? "").data(using: .utf8) ?? Data()
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - MisskeyRequestPerforming

/// Records each Misskey REST call and decodes a canned JSON body into the
/// requested type. Mirrors `FakeRequestPerformer` for the Misskey JSON-body seam;
/// an empty/absent `responseJSON` decodes as `{}` so the void endpoints
/// (`Misskey.EmptyResponse`) are exercised without a network.
final class FakeMisskeyRequestPerformer: MisskeyRequestPerforming {
    struct Call {
        let url: URL
        let body: [String: Any]
    }

    private(set) var calls: [Call] = []
    var lastCall: Call? { calls.last }

    var responseJSON: String?
    var error: Error?

    func perform<Response: Decodable & Sendable>(
        url: URL,
        body: [String: Any],
        expecting type: Response.Type
    ) async throws -> Response {
        calls.append(Call(url: url, body: body))
        if let error { throw error }
        let raw = responseJSON ?? ""
        let data = raw.isEmpty ? Data("{}".utf8) : (raw.data(using: .utf8) ?? Data("{}".utf8))
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - FediverseClient

/// Records the calls the action performer routes through the `FediverseClient`
/// seam, so the performer can be exercised without a live Mastodon/Misskey client.
final class FakeFediverseClient: FediverseClient {
    private(set) var blockedAccountIds: [String] = []
    private(set) var reports: [ReportRequest] = []

    /// When set, the write-path methods throw this after recording the call.
    var errorToThrow: Error?

    func fetchHomeTimeline() async throws -> [any StatusAdaptor] { [] }
    func fetchNotifications() async throws -> [any NotificationAdaptor] { [] }
    func resolveStatus(id: String) async throws -> any StatusAdaptor { FakeStatusAdaptor(id: id) }

    func post(content: String, visibility: StatusVisibility, replyTo: String?) async throws {}

    func favourite(id: String) async throws {}
    func unfavourite(id: String) async throws {}
    func reblog(id: String) async throws {}
    func unreblog(id: String) async throws {}
    func delete(id: String) async throws {}

    func block(accountId: String) async throws {
        blockedAccountIds.append(accountId)
        if let errorToThrow { throw errorToThrow }
    }

    func report(_ request: ReportRequest) async throws {
        reports.append(request)
        if let errorToThrow { throw errorToThrow }
    }
}

// MARK: - Performer

enum FakePerformerError: Error {
    case noResolveResult
}

/// Records the calls the masking flow routes through the performer seam so tests
/// can assert "API call, then swap in a masked copy" behaviour without a live
/// `MastodonClient`.
final class FakePerformer: StatusModelActionPerformer {
    private(set) var reblogCount = 0
    private(set) var unreblogCount = 0
    private(set) var favouriteCount = 0
    private(set) var unfavouriteCount = 0
    private(set) var deleteCount = 0
    private(set) var resolveCount = 0
    private(set) var composeReplyCount = 0
    private(set) var blockCount = 0
    private(set) var reportCount = 0

    private(set) var lastReblogId: String?
    private(set) var lastUnreblogId: String?
    private(set) var lastFavouriteId: String?
    private(set) var lastUnfavouriteId: String?
    private(set) var lastDeleteId: String?
    private(set) var lastResolveId: String?
    private(set) var lastComposeReplyId: String?
    private(set) var lastBlockedAccountId: String?
    private(set) var lastReport: ReportRequest?

    /// When set, `wantsResolve` returns this adaptor; otherwise it throws.
    var resolveResult: StatusAdaptor?
    /// When set, the write-path methods throw this error after recording the call.
    var errorToThrow: Error?

    func statusModel(wantsReblog status: StatusAdaptor, model: any StatusModelBase) async throws {
        reblogCount += 1
        lastReblogId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsUnreblog status: StatusAdaptor, model: any StatusModelBase) async throws {
        unreblogCount += 1
        lastUnreblogId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsFavourite status: StatusAdaptor, model: any StatusModelBase) async throws {
        favouriteCount += 1
        lastFavouriteId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsUnfavourite status: StatusAdaptor, model: any StatusModelBase) async throws {
        unfavouriteCount += 1
        lastUnfavouriteId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsDelete status: StatusAdaptor, model: any StatusModelBase) async throws {
        deleteCount += 1
        lastDeleteId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsResolve statusId: String, model: any StatusModelBase) async throws -> StatusAdaptor {
        resolveCount += 1
        lastResolveId = statusId
        guard let resolveResult else {
            throw FakePerformerError.noResolveResult
        }
        return resolveResult
    }

    func statusModel(wantsComposeReplyTo status: StatusAdaptor, model: any StatusModelBase) async throws {
        composeReplyCount += 1
        lastComposeReplyId = status.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsBlockAuthorOf status: StatusAdaptor, model: any StatusModelBase) async throws {
        blockCount += 1
        lastBlockedAccountId = status.account.id
        if let errorToThrow { throw errorToThrow }
    }

    func statusModel(wantsReport request: ReportRequest, model: any StatusModelBase) async throws {
        reportCount += 1
        lastReport = request
        if let errorToThrow { throw errorToThrow }
    }
}

// MARK: - Helpers

/// Awaits a round-trip through the main dispatch queue so that any block the
/// production code scheduled via `DispatchQueue.main.async` (e.g. the masked
/// replacement in `StatusModelBase.withReplacingOperation`) has executed before
/// the test asserts.
func flushMainQueue() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            continuation.resume()
        }
    }
}
