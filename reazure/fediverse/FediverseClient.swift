//
//  FediverseClient.swift
//  reazure
//

import Foundation

/// The server-agnostic REST surface the session/timeline/action layers depend on.
///
/// Conformers (`MastodonClient`, `MisskeyClient`) return the shared adaptor
/// protocols rather than their own wire types, so `SessionManager`, the timeline
/// fetch closures, and the action performer never mention a concrete backend.
/// Backend-specific semantics (e.g. Misskey favourite ↔ ⭐ reaction, boost ↔
/// renote) are hidden inside each conformer behind these uniform method names.
///
/// The method names are deliberately distinct from `MastodonClient`'s existing
/// raw REST methods (`homeTimeline()`, `favourite(statusId:)`, …) so that
/// conformance does not collide with — or change the witnesses of — those
/// methods, keeping the raw-method tests intact.
protocol FediverseClient: AnyObject {
    func fetchHomeTimeline() async throws -> [any StatusAdaptor]
    func fetchNotifications() async throws -> [any NotificationAdaptor]
    func resolveStatus(id: String) async throws -> any StatusAdaptor

    func post(content: String, visibility: StatusVisibility, replyTo: String?) async throws

    func favourite(id: String) async throws
    func unfavourite(id: String) async throws
    func reblog(id: String) async throws
    func unreblog(id: String) async throws
    func delete(id: String) async throws

    // MARK: - moderation

    /// Blocks an account. Both backends stop delivering the blocked account's
    /// posts afterwards; hiding what is already on screen is the caller's job
    /// (see `SharedClient.applyBlock(accountId:)`).
    func block(accountId: String) async throws

    /// Files an abuse report with the user's own server moderators.
    func report(_ request: ReportRequest) async throws
}
