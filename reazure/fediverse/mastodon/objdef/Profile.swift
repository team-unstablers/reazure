//
//  Profile.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

extension Mastodon {
    struct UserProfile: Codable {
        let id: String
        let username: String
        let acct: String
        
        let url: String?
        
        let display_name: String
        
        let avatar: String
        
        let emojis: [CustomEmoji]
    }
}

class MastodonAccountAdaptor: AccountAdaptor {
    let _account: Mastodon.UserProfile
    
    var id: String { _account.id }
    var username: String { _account.username }
    var acct: String { _account.acct }
    
    var url: String? { _account.url }
    
    var displayName: String { _account.display_name }
    var locked: Bool { false }
    var bot: Bool { false }
    
    var avatar: String { _account.avatar }
    
    var emojis: [EmojiAdaptor]
    
    init(from account: Mastodon.UserProfile) {
        self._account = account
        
        self.emojis = self._account.emojis.map { MastodonEmojiAdaptor(from: $0) }
    }
}


