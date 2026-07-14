//
//  MisskeyAPI.swift
//  reazure
//
//  Misskey REST client. Mirrors `MastodonClient`, but Misskey's API differs in
//  two ways that keep it from reusing the Mastodon transport:
//    - every call is a POST with an `application/json` body, and
//    - auth is the token carried in the body as `i` (not a Bearer header).
//  Backend-specific semantics (favourite ⇔ ⭐ reaction, boost ⇔ renote) are
//  hidden here behind the uniform `FediverseClient` method names.
//

import Foundation
import Alamofire

struct MisskeyEndpoint: RawRepresentable {
    var rawValue: String

    static let i = MisskeyEndpoint(rawValue: "/api/i")
    static let notesTimeline = MisskeyEndpoint(rawValue: "/api/notes/timeline")
    static let iNotifications = MisskeyEndpoint(rawValue: "/api/i/notifications")
    static let notesShow = MisskeyEndpoint(rawValue: "/api/notes/show")
    static let notesCreate = MisskeyEndpoint(rawValue: "/api/notes/create")
    static let notesDelete = MisskeyEndpoint(rawValue: "/api/notes/delete")
    static let notesUnrenote = MisskeyEndpoint(rawValue: "/api/notes/unrenote")
    static let reactionsCreate = MisskeyEndpoint(rawValue: "/api/notes/reactions/create")
    static let reactionsDelete = MisskeyEndpoint(rawValue: "/api/notes/reactions/delete")
    static let blockingCreate = MisskeyEndpoint(rawValue: "/api/blocking/create")
    static let usersReportAbuse = MisskeyEndpoint(rawValue: "/api/users/report-abuse")
    static let meta = MisskeyEndpoint(rawValue: "/api/meta")

    static func miAuthCheck(session: String) -> MisskeyEndpoint {
        return MisskeyEndpoint(rawValue: "/api/miauth/\(session)/check")
    }

    func url(for server: String) -> URL {
        return URL(string: "https://\(server.sanitizeServerAddress())\(self.rawValue)")!
    }
}

/// The JSON-body transport seam behind `MisskeyClient`. Distinct from the
/// Mastodon `RequestPerforming` because Misskey needs a JSON body (non-string
/// values, e.g. `limit: Int`) and tolerates empty `204` responses.
protocol MisskeyRequestPerforming {
    func perform<Response: Decodable & Sendable>(
        url: URL,
        body: [String: Any],
        expecting type: Response.Type
    ) async throws -> Response
}

/// Live `MisskeyRequestPerforming` backed by Alamofire. POSTs a JSON body and
/// substitutes `{}` for an empty response body so `204`/no-content endpoints
/// decode into `Misskey.EmptyResponse` instead of failing.
struct AlamofireMisskeyRequestPerformer: MisskeyRequestPerforming {
    func perform<Response: Decodable & Sendable>(
        url: URL,
        body: [String: Any],
        expecting type: Response.Type
    ) async throws -> Response {
        let response = await AF.request(url,
                                        method: .post,
                                        parameters: body,
                                        encoding: JSONEncoding.default)
            .validate()
            .serializingData()
            .response

        guard let data = response.value else {
            let error = response.error!
            if let underlying = error.underlyingError, underlying is DecodingError {
                throw FediverseAPIError.decodingError(originError: underlying as! DecodingError)
            }
            throw FediverseAPIError.serverError(originError: error)
        }

        let payload = data.isEmpty ? Data("{}".utf8) : data

        do {
            return try JSONDecoder().decode(type, from: payload)
        } catch let error as DecodingError {
            throw FediverseAPIError.decodingError(originError: error)
        }
    }
}

class MisskeyClient {
    let account: Account

    private let performer: MisskeyRequestPerforming

    init(using account: Account, performer: MisskeyRequestPerforming = AlamofireMisskeyRequestPerformer()) {
        self.account = account
        self.performer = performer
    }

    /// Injects the auth token into the body (`i`) and performs the POST.
    private func request<Response>(
        to endpoint: MisskeyEndpoint,
        body: [String: Any] = [:],
        expects type: Response.Type
    ) async throws -> Response where Response: Decodable & Sendable {
        var body = body
        body["i"] = account.accessToken

        let url = endpoint.url(for: account.server.address)
        return try await performer.perform(url: url, body: body, expecting: type)
    }

    func i() async throws -> Misskey.User {
        return try await request(to: .i, expects: Misskey.User.self)
    }

    func homeTimeline(limit: Int = 40) async throws -> [Misskey.Note] {
        return try await request(to: .notesTimeline,
                                 body: ["limit": limit],
                                 expects: [Misskey.Note].self)
    }

    func notifications(limit: Int = 40) async throws -> [Misskey.Notification] {
        return try await request(to: .iNotifications,
                                 body: ["limit": limit],
                                 expects: [Misskey.Notification].self)
    }

    func show(noteId: String) async throws -> Misskey.Note {
        return try await request(to: .notesShow,
                                 body: ["noteId": noteId],
                                 expects: Misskey.Note.self)
    }

    func createNote(text: String?,
                    visibility: String,
                    replyId: String? = nil,
                    renoteId: String? = nil,
                    visibleUserIds: [String]? = nil) async throws -> Misskey.Note {
        var body: [String: Any] = ["visibility": visibility]
        if let text = text { body["text"] = text }
        if let replyId = replyId { body["replyId"] = replyId }
        if let renoteId = renoteId { body["renoteId"] = renoteId }
        if let visibleUserIds = visibleUserIds { body["visibleUserIds"] = visibleUserIds }

        let response = try await request(to: .notesCreate,
                                         body: body,
                                         expects: Misskey.CreateNoteResponse.self)
        return response.createdNote
    }

    func deleteNote(noteId: String) async throws {
        _ = try await request(to: .notesDelete,
                              body: ["noteId": noteId],
                              expects: Misskey.EmptyResponse.self)
    }

    func unrenote(noteId: String) async throws {
        _ = try await request(to: .notesUnrenote,
                              body: ["noteId": noteId],
                              expects: Misskey.EmptyResponse.self)
    }

    func reactionCreate(noteId: String, reaction: String) async throws {
        _ = try await request(to: .reactionsCreate,
                              body: ["noteId": noteId, "reaction": reaction],
                              expects: Misskey.EmptyResponse.self)
    }

    func reactionDelete(noteId: String) async throws {
        _ = try await request(to: .reactionsDelete,
                              body: ["noteId": noteId],
                              expects: Misskey.EmptyResponse.self)
    }

    func blockingCreate(userId: String) async throws {
        _ = try await request(to: .blockingCreate,
                              body: ["userId": userId],
                              expects: Misskey.EmptyResponse.self)
    }

    /// `POST /api/users/report-abuse`. The server requires a non-empty comment
    /// (1–2048 characters) and takes no note reference, so the caller is expected
    /// to have folded the reported note into `comment` (see `misskeyComment`).
    func reportAbuse(userId: String, comment: String) async throws {
        _ = try await request(to: .usersReportAbuse,
                              body: ["userId": userId, "comment": String(comment.prefix(2048))],
                              expects: Misskey.EmptyResponse.self)
    }

    // MARK: - static (config / login)

    /// Instance metadata (`POST /api/meta`, unauthenticated) — supplies the max
    /// note length used for the composer counter.
    static func meta(of server: String) async throws -> Misskey.Meta {
        let url = MisskeyEndpoint.meta.url(for: server)
        return try await AlamofireMisskeyRequestPerformer()
            .perform(url: url, body: [:], expecting: Misskey.Meta.self)
    }

    /// Completes the MiAuth flow: exchanges the approved session UUID for a token
    /// and the authenticated user (`POST /api/miauth/<session>/check`).
    static func miAuthCheck(host: String, session: String) async throws -> Misskey.MiAuthResult {
        let url = MisskeyEndpoint.miAuthCheck(session: session).url(for: host)
        return try await AlamofireMisskeyRequestPerformer()
            .perform(url: url, body: [:], expecting: Misskey.MiAuthResult.self)
    }
}

extension MisskeyClient: FediverseClient {
    func fetchHomeTimeline() async throws -> [any StatusAdaptor] {
        try await homeTimeline().map { MisskeyStatusAdaptor(from: $0) }
    }

    func fetchNotifications() async throws -> [any NotificationAdaptor] {
        try await notifications().map { MisskeyNotificationAdaptor(from: $0) }
    }

    func resolveStatus(id: String) async throws -> any StatusAdaptor {
        MisskeyStatusAdaptor(from: try await show(noteId: id))
    }

    func post(content: String, visibility: StatusVisibility, replyTo: String?) async throws {
        _ = try await createNote(text: content,
                                 visibility: visibility.misskeyValue,
                                 replyId: replyTo)
    }

    /// Favourite ⇔ apply the `⭐` reaction.
    func favourite(id: String) async throws {
        try await reactionCreate(noteId: id, reaction: "⭐")
    }

    func unfavourite(id: String) async throws {
        try await reactionDelete(noteId: id)
    }

    /// Boost ⇔ create a renote (a text-less note pointing at the target).
    func reblog(id: String) async throws {
        _ = try await createNote(text: nil, visibility: "public", renoteId: id)
    }

    func unreblog(id: String) async throws {
        try await unrenote(noteId: id)
    }

    func delete(id: String) async throws {
        try await deleteNote(noteId: id)
    }

    func block(accountId: String) async throws {
        try await blockingCreate(userId: accountId)
    }

    /// Report ⇔ `users/report-abuse`, which reports a *user*, not a note.
    func report(_ request: ReportRequest) async throws {
        try await reportAbuse(userId: request.accountId, comment: request.misskeyComment)
    }
}

private extension ReportRequest {
    /// Misskey has no per-note report endpoint: `users/report-abuse` takes a user
    /// id and one free-form comment, which must be non-empty. So the category and
    /// the reported note's URL are folded into the comment — the same thing the
    /// Misskey web UI does when you report from a note.
    var misskeyComment: String {
        var lines: [String] = ["[\(category.rawValue)]"]

        let comment = self.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !comment.isEmpty {
            lines.append(comment)
        }

        if let statusUrl = statusUrl {
            lines.append(statusUrl)
        }

        return lines.joined(separator: "\n")
    }
}
