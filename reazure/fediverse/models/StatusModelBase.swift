//
//  TimelineItemBase.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

protocol StatusModelActionPerformer: AnyObject {
    func statusModel(wantsReblog status: StatusAdaptor, model: any StatusModelBase) async throws
    func statusModel(wantsUnreblog status: StatusAdaptor, model: any StatusModelBase) async throws
    func statusModel(wantsFavourite status: StatusAdaptor, model: any StatusModelBase) async throws
    func statusModel(wantsUnfavourite status: StatusAdaptor, model: any StatusModelBase) async throws
    
    func statusModel(wantsDelete status: StatusAdaptor, model: any StatusModelBase) async throws
    
    func statusModel(wantsResolve statusId: String, model: any StatusModelBase) async throws -> StatusAdaptor
    
    func statusModel(wantsComposeReplyTo status: StatusAdaptor, model: any StatusModelBase) async throws
}

protocol StatusModelBase: AnyObject, Identifiable, Hashable {
    typealias Performer = StatusModelActionPerformer
    
    var performer: Performer? { get set }
    
    var id: String { get }
    var status: StatusAdaptor { get set }
    var parents: [StatusAdaptor] { get set }
    
    var expandedDepth: Int { get set }
    
    
    var resolving: Bool { get set }
}

extension StatusModelBase {
    func resolve(depth: Int) -> StatusAdaptor? {
        if depth == 0 {
            return status
        }
        
        if depth > parents.count {
            return nil
        }
        
        return parents[depth - 1]
    }
    
    private func replace(at depth: Int, with status: StatusAdaptor) {
        if depth == 0 {
            self.status = status
        } else {
            parents[depth - 1] = status
        }
    }
    
    private func withReplacingOperation(at depth: Int, _ operation: (StatusAdaptor) async throws -> StatusAdaptor) async throws {
        guard let status = resolve(depth: depth) else {
            return
        }
        
        let newStatus = try await operation(status)
        
        DispatchQueue.main.async {
            self.replace(at: depth, with: newStatus)
        }
    }
    
    func toggleReblog(of depth: Int) async throws {
        try await withReplacingOperation(at: depth) { status in
            if !status.reblogged {
                try await self.performer?.statusModel(wantsReblog: status, model: self)
                return status.mask(reblogged: true)
            } else {
                try await self.performer?.statusModel(wantsUnreblog: status, model: self)
                return status.mask(reblogged: false)
            }
        }
    }
    
    func toggleFavourite(of depth: Int) async throws {
        try await withReplacingOperation(at: depth) { status in
            if !status.favourited {
                try await self.performer?.statusModel(wantsFavourite: status, model: self)
                return status.mask(favourited: true)
            } else {
                try await self.performer?.statusModel(wantsUnfavourite: status, model: self)
                return status.mask(favourited: false)
            }
        }
    }
    
    func delete(depth: Int) async throws {
        // TODO: 모델 자체가 지워져야 하는 오퍼레이션이기 때문에 설계에 대해 더 생각해봐야 함
        try await withReplacingOperation(at: depth) { status in
            try? await performer?.statusModel(wantsDelete: status, model: self)
            return status.mask(deleted: true)
        }
    }
    
    func composeReply(to depth: Int) async throws {
        guard let status = resolve(depth: depth) else {
            return
        }
        
        try await performer?.statusModel(wantsComposeReplyTo: status, model: self)
    }
    
    func resolveParent(of status: StatusAdaptor) async throws {
        guard let parentId = status.canonical.replyToId else {
            return
        }
        
        if (self.resolving) {
            return
        }
        
        DispatchQueue.main.async {
            self.resolving = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.resolving = false
            }
        }
        
        guard let parent = try await performer?.statusModel(wantsResolve: parentId, model: self) else {
            return
        }
        
        DispatchQueue.main.async {
            self.parents.append(parent)
        }
    }
}
