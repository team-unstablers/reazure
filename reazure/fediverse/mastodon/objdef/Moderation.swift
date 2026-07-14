//
//  Moderation.swift
//  reazure
//
//  Wire types for the moderation endpoints (block / report). Both are decoded
//  only far enough to confirm the server accepted the call — the app acts on the
//  local mask, not on the returned object — so a field the server happens to omit
//  cannot turn a successful block into a thrown error.
//

extension Mastodon {
    /// `POST /api/v1/accounts/:id/block` → Relationship.
    struct Relationship: Codable {
        let id: String
    }

    /// `POST /api/v1/reports` → Report.
    struct Report: Codable {
        let id: String
    }
}
