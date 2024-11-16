//
//  OAuthApplication.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

extension Mastodon {
    struct OAuthApplication: Codable {
        let id: String
        let name: String
        let website: String
        let scopes: [String]
        let client_id: String
        let client_secret: String
    }
    
    struct OAuthToken: Codable {
        let access_token: String
        let token_type: String
        let scope: String
        let created_at: Int
    }
}
