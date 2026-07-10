//
//  MastodonActionPerformer.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

import Combine

/// Concrete `StatusModelActionPerformer` for Mastodon backends.
///
/// Extracted from `SharedClient` so that the write paths of every
/// `StatusModel`/`NotificationModel` no longer route back through the shared
/// hub. The active `MastodonClient` is mirrored in via `client` (updated by the
/// owner whenever the account changes) and the compose `replyTo` subject is a
/// shared reference owned by `SharedClient`.
final class MastodonActionPerformer: StatusModelActionPerformer {
    /// The active REST client. Updated by the owner (`SharedClient`) on account
    /// change; `nil` while signed out.
    var client: MastodonClient?

    /// Shared compose subject owned by `SharedClient`. Subscribed to by
    /// `PostArea`; this performer only publishes onto it.
    private let replyTo: CurrentValueSubject<StatusAdaptor?, Never>

    init(client: MastodonClient? = nil, replyTo: CurrentValueSubject<StatusAdaptor?, Never>) {
        self.client = client
        self.replyTo = replyTo
    }

    func statusModel(wantsReblog status: any StatusAdaptor, model: any StatusModelBase) async throws {
        _ = try await self.client?.reblog(statusId: status.id)
    }

    func statusModel(wantsUnreblog status: any StatusAdaptor, model: any StatusModelBase) async throws {
        _ = try await self.client?.unreblog(statusId: status.id)
    }

    func statusModel(wantsFavourite status: any StatusAdaptor, model: any StatusModelBase) async throws {
        _ = try await self.client?.favourite(statusId: status.id)
    }

    func statusModel(wantsUnfavourite status: any StatusAdaptor, model: any StatusModelBase) async throws {
        _ = try await self.client?.unfavourite(statusId: status.id)
    }

    func statusModel(wantsDelete status: any StatusAdaptor, model: any StatusModelBase) async throws {
        _ = try await self.client?.deleteStatus(statusId: status.id)
    }

    func statusModel(wantsResolve statusId: String, model: any StatusModelBase) async throws -> any StatusAdaptor {
        guard let status = try await self.client?.status(of: statusId) else {
            // FIXME!!
            throw FediverseAPIError.unknownError(originError: nil)
        }
        return MastodonStatusAdaptor(from: status)
    }

    func statusModel(wantsComposeReplyTo status: any StatusAdaptor, model: any StatusModelBase) async throws {
        self.replyTo.send(status)
    }
}
