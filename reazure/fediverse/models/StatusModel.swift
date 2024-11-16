//
//  Status.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI

class StatusModel: ObservableObject {
    @Published
    var status: StatusAdaptor
    
    @Published
    var parents: [StatusAdaptor] = []
    
    @Published
    var expandedDepth: Int = 0
    
    @Published
    var resolving: Bool = false
    
    init(adaptor status: StatusAdaptor) {
        self.status = status
    }
}

extension StatusModel: Hashable, Equatable, Identifiable {
    static func == (lhs: StatusModel, rhs: StatusModel) -> Bool {
        return lhs.status.id == rhs.status.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(status.id)
    }
    
    var id: String {
        return status.id
    }
}

extension StatusModel {
    func resolveParent(of status: StatusAdaptor, using client: MastodonClient) {
        guard let parentId = (status.reblog ?? status).replyToId else {
            return
        }
        
        if (self.resolving) {
            return
        }
        
        self.resolving = true
        
        
        Task {
            defer {
                DispatchQueue.main.async {
                    self.resolving = false
                }
            }
            do {
                let parent = try await client.status(of: parentId)
                
                DispatchQueue.main.async {
                    self.parents.append(MastodonStatusAdaptor(from: parent))
                }
            } catch {
                print("Failed to resolve parent: \(error)")
            }
        }
    }
}
