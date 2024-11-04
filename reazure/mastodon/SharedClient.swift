//
//  AccountManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation

class SharedClient: ObservableObject {
    @Published
    var account: Account? {
        didSet {
            if let account = account {
                client = MastodonClient(using: account)
            } else {
                client = nil
            }
        }
    }
    
    
    var client: MastodonClient?
}
