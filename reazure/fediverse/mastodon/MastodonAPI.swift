//
//  MastodonAPI.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation
import Alamofire

struct MastodonEndpoint: RawRepresentable {
    var rawValue: String
    
    static let nodeInfo = MastodonEndpoint(rawValue: "/nodeinfo/2.0")
    
    static let oauthAuthorize = MastodonEndpoint(rawValue: "/oauth/authorize")
    static let oauthToken = MastodonEndpoint(rawValue: "/oauth/token")

    static let registerApp = MastodonEndpoint(rawValue: "/api/v1/apps")
    
    static let verifyCredentials = MastodonEndpoint(rawValue: "/api/v1/accounts/verify_credentials")
    
    static let statuses = MastodonEndpoint(rawValue: "/api/v1/statuses")

    static let notifications = MastodonEndpoint(rawValue: "/api/v1/notifications")
    
    static let homeTimeline = MastodonEndpoint(rawValue: "/api/v1/timelines/home")
    
    static let streaming = MastodonEndpoint(rawValue: "/api/v1/streaming")
    
    static func status(of statusId: String) -> MastodonEndpoint {
        return MastodonEndpoint(rawValue: "/api/v1/statuses/\(statusId)")
    }
    
    static func favourite(of statusId: String) -> MastodonEndpoint {
        return MastodonEndpoint(rawValue: "/api/v1/statuses/\(statusId)/favourite")
    }
    
    static func unfavourite(of statusId: String) -> MastodonEndpoint {
        return MastodonEndpoint(rawValue: "/api/v1/statuses/\(statusId)/unfavourite")
    }
    
    static func reblog(of statusId: String) -> MastodonEndpoint {
        return MastodonEndpoint(rawValue: "/api/v1/statuses/\(statusId)/reblog")
    }
    
    static func unreblog(of statusId: String) -> MastodonEndpoint {
        return MastodonEndpoint(rawValue: "/api/v1/statuses/\(statusId)/unreblog")
    }

    func urlString(for server: String) -> String {
        return "https://\(server.sanitizeServerAddress())\(self.rawValue)"
    }
    
    func url(for server: String) -> URL {
        return URL(string: self.urlString(for: server))!
    }
}

class MastodonClient {
    static func nodeInfo(of server: String) async throws -> Mastodon.NodeInfo? {
        let url = MastodonEndpoint.nodeInfo.url(for: server)
        let response = await AF.request(url)
            .validate()
            .serializingDecodable(Mastodon.NodeInfo.self)
            .response
        
        if let error = response.error {
            throw error
        }
        
        return response.value
    }
    
    static func createClient(at server: String) async throws -> Mastodon.OAuthApplication {
        let url = MastodonEndpoint.registerApp.url(for: server)
        let parameters: [String: Any] = [
            "client_name": "re;azure",
            "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
            "scopes": "read write follow",
            "website": "https://reazure.unstabler.pl"
        ]
        
        let response = await AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate()
            .serializingDecodable(Mastodon.OAuthApplication.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    static func obtainOAuthToken(from server: String, application: Mastodon.OAuthApplication, code: String) async throws -> Mastodon.OAuthToken {
        let url = MastodonEndpoint.oauthToken.url(for: server)
        let parameters: [String: Any] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": application.client_id,
            "client_secret": application.client_secret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob"
        ]
        
        let response = await AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate()
            .serializingDecodable(Mastodon.OAuthToken.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    let account: Account
    
    init(using account: Account) {
        self.account = account
    }
    
    func verifyCredentials() async throws -> Mastodon.UserProfile {
        let url = MastodonEndpoint.verifyCredentials.url(for: account.server.address)
    
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.UserProfile.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func status(of statusId: String) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.status(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func postStatus(_ status: String, visibility: Mastodon.Visibility, replyTo: String? = nil) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.statuses.url(for: account.server.address)
        
        var parameters = [
            "status": status,
            "visibility": visibility.rawValue
        ]
        
        if let replyTo = replyTo {
            parameters["in_reply_to_id"] = replyTo
        }
            
        let response = await AF.request(url, method: .post, parameters: parameters, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func notifications() async throws -> [Mastodon.Notification] {
        let url = MastodonEndpoint.notifications.url(for: account.server.address)
        
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable([Mastodon.Notification].self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func homeTimeline() async throws -> [Mastodon.Status] {
        let url = MastodonEndpoint.homeTimeline.url(for: account.server.address)
        
            
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable([Mastodon.Status].self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func favourite(statusId: String) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.favourite(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func unfavourite(statusId: String) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.unfavourite(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func reblog(statusId: String) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.reblog(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func unreblog(statusId: String) async throws -> Mastodon.Status {
        let url = MastodonEndpoint.unreblog(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Mastodon.Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }

}

fileprivate extension String {
    func sanitizeServerAddress() -> String {
        var server = self
        if server.hasPrefix("https://") {
            server.removeFirst("https://".count)
        } else if server.hasPrefix("http://") {
            server.removeFirst("http://".count)
        }
        
        if server.hasSuffix("/") {
            server.removeLast()
        }
        
        return server
    }
}
