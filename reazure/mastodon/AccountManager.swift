//
//  AccountManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation

class AccountManager: ObservableObject {
    @Published
    var accounts: [Account] = []
    
    var isEmpty: Bool {
        return accounts.isEmpty
    }
    
    var count: Int {
        return accounts.count
    }
    
    /**
     Load accounts from UserDefaults
     */
    func refresh() {
        if let data = UserDefaults.standard.data(forKey: "accounts") {
            let accounts = try! JSONDecoder().decode([Account].self, from: data)
            self.accounts = accounts
        }
    }
    
    func save() {
        let data = try! JSONEncoder().encode(accounts)
        UserDefaults.standard.set(data, forKey: "accounts")
    }
    
    func add(_ account: Account) {
        accounts.append(account)
        save()
    }
    
    func remove(_ account: Account) {
        accounts.removeAll { $0 == account }
        save()
    }
    
    func removeAll() {
        accounts.removeAll()
        save()
    }
}
