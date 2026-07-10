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

    private(set) var lastReblogId: String?
    private(set) var lastUnreblogId: String?
    private(set) var lastFavouriteId: String?
    private(set) var lastUnfavouriteId: String?
    private(set) var lastDeleteId: String?
    private(set) var lastResolveId: String?
    private(set) var lastComposeReplyId: String?

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
