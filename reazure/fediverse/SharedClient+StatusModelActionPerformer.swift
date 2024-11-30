//
//  SharedClient+.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

extension SharedClient: StatusModelActionPerformer {
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
