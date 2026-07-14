//
//  MastodonActionPerformer.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

import Combine

/// Concrete `StatusModelActionPerformer` driving any `FediverseClient`.
///
/// Extracted from `SharedClient` so that the write paths of every
/// `StatusModel`/`NotificationModel` no longer route back through the shared
/// hub. The active client is mirrored in via `client` (updated by the owner
/// whenever the account changes) and the compose `replyTo` subject is a shared
/// reference owned by `SharedClient`. Because it talks to the `FediverseClient`
/// protocol, backend-specific semantics (Misskey favourite ↔ reaction, boost ↔
/// renote, …) stay inside the client conformer and this performer is shared
/// across servers.
final class FediverseActionPerformer: StatusModelActionPerformer {
    /// The active REST client. Updated by the owner (`SharedClient`) on account
    /// change; `nil` while signed out.
    var client: (any FediverseClient)?

    /// Shared compose subject owned by `SharedClient`. Subscribed to by
    /// `PostArea`; this performer only publishes onto it.
    private let replyTo: CurrentValueSubject<StatusAdaptor?, Never>

    /// Called with the blocked account id once the server has accepted a block.
    /// A block is the one action whose effect is not confined to the model that
    /// raised it — every row by that author has to be hidden — so the owner
    /// (`SharedClient`, which holds the timelines) applies it.
    private let didBlockAccount: (String) -> Void

    init(client: (any FediverseClient)? = nil,
         replyTo: CurrentValueSubject<StatusAdaptor?, Never>,
         didBlockAccount: @escaping (String) -> Void = { _ in }) {
        self.client = client
        self.replyTo = replyTo
        self.didBlockAccount = didBlockAccount
    }

    func statusModel(wantsReblog status: any StatusAdaptor, model: any StatusModelBase) async throws {
        try await self.client?.reblog(id: status.id)
    }

    func statusModel(wantsUnreblog status: any StatusAdaptor, model: any StatusModelBase) async throws {
        try await self.client?.unreblog(id: status.id)
    }

    func statusModel(wantsFavourite status: any StatusAdaptor, model: any StatusModelBase) async throws {
        try await self.client?.favourite(id: status.id)
    }

    func statusModel(wantsUnfavourite status: any StatusAdaptor, model: any StatusModelBase) async throws {
        try await self.client?.unfavourite(id: status.id)
    }

    func statusModel(wantsDelete status: any StatusAdaptor, model: any StatusModelBase) async throws {
        try await self.client?.delete(id: status.id)
    }

    func statusModel(wantsResolve statusId: String, model: any StatusModelBase) async throws -> any StatusAdaptor {
        guard let status = try await self.client?.resolveStatus(id: statusId) else {
            // FIXME!!
            throw FediverseAPIError.unknownError(originError: nil)
        }
        return status
    }

    func statusModel(wantsComposeReplyTo status: any StatusAdaptor, model: any StatusModelBase) async throws {
        self.replyTo.send(status)
    }

    func statusModel(wantsBlockAuthorOf status: any StatusAdaptor, model: any StatusModelBase) async throws {
        guard let client = self.client else {
            return
        }

        let accountId = status.account.id

        try await client.block(accountId: accountId)
        self.didBlockAccount(accountId)
    }

    func statusModel(wantsReport request: ReportRequest, model: any StatusModelBase) async throws {
        try await self.client?.report(request)
    }

    /// Submits a new post through the active REST client.
    ///
    /// Not part of the `StatusModelActionPerformer` protocol — this is the
    /// compose seam used by the post composer, routed here so no view touches
    /// the client directly.
    func post(_ request: PostRequest) async throws {
        try await self.client?.post(content: request.content,
                                    visibility: request.visibility,
                                    replyTo: request.replyTo)
    }
}

/// Back-compat alias: the performer is now backend-agnostic, but existing call
/// sites and tests still reference `MastodonActionPerformer`.
typealias MastodonActionPerformer = FediverseActionPerformer
