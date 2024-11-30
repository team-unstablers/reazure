//
//  Status.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI


class StatusModel: StatusModelBase, ObservableObject {
    weak var performer: Performer?
    
    @Published
    var status: StatusAdaptor
    
    @Published
    var parents: [StatusAdaptor] = []
    
    @Published
    var expandedDepth: Int = 0
    
    @Published
    var resolving: Bool = false
    
    init(adaptor status: StatusAdaptor, performer: Performer? = nil) {
        self.status = status
        self.performer = performer
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
