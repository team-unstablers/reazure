//
//  Account.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

typealias fedi_id_t = String

struct Account: Codable {
    var id: fedi_id_t
    var username: String
    
    var server: FediverseServer
    
    var accessToken: String
}

extension Account: Hashable, Equatable, Identifiable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(server)
    }
    
    static func ==(lhs: Account, rhs: Account) -> Bool {
        return (lhs.id == rhs.id) && (lhs.server == rhs.server)
    }
}
