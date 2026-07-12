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
    
    /// 메인 큐에서 `body`를 동기 실행하고 결과를 반환한다.
    ///
    /// read → 판정 → mask/replace를 하나의 크리티컬 섹션으로 묶기 위한 헬퍼다.
    /// 낙관적 조작들은 각각 독립적인 `Task`로 발사되는데, 각 조작의 read-modify-write를
    /// 메인 큐에서 직렬화함으로써 "동시에 favourite/boost를 조작하면 한쪽만 반영되는"
    /// read-modify-write 레이스를 제거한다.
    private func onMain<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            DispatchQueue.main.async { cont.resume(returning: body()) }
        }
    }

    func toggleReblog(of depth: Int) async throws {
        // 1) 낙관적 갱신: 현재 상태를 읽어 방향을 정하고 즉시 마스크한다. (메인, 원자적)
        let plan: (target: Bool, status: StatusAdaptor)? = await onMain {
            guard let current = self.resolve(depth: depth) else { return nil }
            let target = !current.reblogged
            self.replace(at: depth, with: current.mask(reblogged: target))
            return (target, current)
        }
        guard let plan else { return }

        // 2) API를 뒤이어 호출한다.
        do {
            if plan.target {
                try await performer?.statusModel(wantsReblog: plan.status, model: self)
            } else {
                try await performer?.statusModel(wantsUnreblog: plan.status, model: self)
            }
        } catch {
            // 3) 실패 롤백: 그 사이 다른 조작이 값을 바꾸지 않았을 때만 되돌린다.
            await onMain {
                guard let current = self.resolve(depth: depth),
                      current.reblogged == plan.target else { return }
                self.replace(at: depth, with: current.mask(reblogged: !plan.target))
            }
            throw error
        }
    }

    func toggleFavourite(of depth: Int) async throws {
        // 1) 낙관적 갱신: 현재 상태를 읽어 방향을 정하고 즉시 마스크한다. (메인, 원자적)
        let plan: (target: Bool, status: StatusAdaptor)? = await onMain {
            guard let current = self.resolve(depth: depth) else { return nil }
            let target = !current.favourited
            self.replace(at: depth, with: current.mask(favourited: target))
            return (target, current)
        }
        guard let plan else { return }

        // 2) API를 뒤이어 호출한다.
        do {
            if plan.target {
                try await performer?.statusModel(wantsFavourite: plan.status, model: self)
            } else {
                try await performer?.statusModel(wantsUnfavourite: plan.status, model: self)
            }
        } catch {
            // 3) 실패 롤백: 그 사이 다른 조작이 값을 바꾸지 않았을 때만 되돌린다.
            await onMain {
                guard let current = self.resolve(depth: depth),
                      current.favourited == plan.target else { return }
                self.replace(at: depth, with: current.mask(favourited: !plan.target))
            }
            throw error
        }
    }

    func delete(depth: Int) async throws {
        // TODO: 모델 자체가 지워져야 하는 오퍼레이션이기 때문에 설계에 대해 더 생각해봐야 함
        // 1) 낙관적으로 삭제 표시한다. (메인, 원자적)
        let status: StatusAdaptor? = await onMain {
            guard let current = self.resolve(depth: depth) else { return nil }
            self.replace(at: depth, with: current.mask(deleted: true))
            return current
        }
        guard let status else { return }

        // 2) API를 뒤이어 호출하고, 실패하면 삭제 표시를 되돌린다.
        do {
            try await performer?.statusModel(wantsDelete: status, model: self)
        } catch {
            await onMain {
                guard let current = self.resolve(depth: depth), current.deleted else { return }
                self.replace(at: depth, with: current.mask(deleted: false))
            }
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
