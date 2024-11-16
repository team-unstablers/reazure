//
//  Status.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

class StatusModel {
    let status: StatusAdaptor
    
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
