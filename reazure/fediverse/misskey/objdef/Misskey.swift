//
//  Misskey.swift
//  reazure
//
//  Raw Misskey API decodables, namespaced under `Misskey` (mirroring the
//  `Mastodon` namespace). Field names match the wire JSON verbatim (camelCase),
//  since the shared `JSON` helper decodes with `.useDefaultKeys`.
//
//  Scope note: emoji reactions and MFM are intentionally out of scope, so
//  per-note `reactions`/`emojis`/`mentions` are deliberately NOT decoded — Codable
//  ignores keys absent from the type, which also sidesteps the dict-vs-array
//  `emojis` shape differences across Misskey versions.
//

import Foundation

enum Misskey {}

extension Misskey {
    struct User: Codable {
        let id: String
        let username: String
        /// Display name; nullable, falls back to `username`.
        let name: String?
        /// Remote host; `nil` for local users.
        let host: String?
        let avatarUrl: String?
        let isBot: Bool?
        let isLocked: Bool?
    }

    struct DriveFile: Codable {
        let id: String
        /// MIME type, e.g. `image/png`.
        let type: String
        let url: String
        let thumbnailUrl: String?
        let comment: String?
        let isSensitive: Bool?
    }

    struct Note: Codable {
        let id: String
        let createdAt: String
        let text: String?
        let cw: String?
        let visibility: String
        let user: User
        let userId: String
        let replyId: String?
        let renoteId: String?
        // `Box` breaks the self-referential value-type size cycle (same pattern as
        // `Mastodon.Status.reblog`).
        let reply: Box<Note>?
        let renote: Box<Note>?
        let files: [DriveFile]?
        /// The reaction the current user has applied, if any. Drives `favourited`.
        let myReaction: String?
        let url: String?
        let uri: String?
    }

    struct Notification: Codable {
        let id: String
        let createdAt: String
        let type: String
        let user: User?
        let userId: String?
        let note: Note?
        let reaction: String?
    }

    struct Meta: Codable {
        let maxNoteTextLength: Int?
    }

    struct MiAuthResult: Codable {
        let ok: Bool
        let token: String?
        let user: User?
    }

    struct CreateNoteResponse: Codable {
        let createdNote: Note
    }

    /// Placeholder for endpoints that return `204 No Content` (or an empty body);
    /// the transport substitutes `{}` before decoding into this.
    struct EmptyResponse: Codable {}
}
