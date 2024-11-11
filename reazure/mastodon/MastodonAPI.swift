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
    static func nodeInfo(of server: String) async throws -> NodeInfo? {
        let url = MastodonEndpoint.nodeInfo.url(for: server)
        let response = await AF.request(url)
            .validate()
            .serializingDecodable(NodeInfo.self)
            .response
        
        if let error = response.error {
            throw error
        }
        
        return response.value
    }
    
    static func createClient(at server: String) async throws -> OAuthApplication {
        let url = MastodonEndpoint.registerApp.url(for: server)
        let parameters: [String: Any] = [
            "client_name": "reazure",
            "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
            "scopes": "read write follow",
            "website": "https://reazure.unstabler.pl"
        ]
        
        let response = await AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .validate()
            .serializingDecodable(OAuthApplication.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    static func obtainOAuthToken(from server: String, application: OAuthApplication, code: String) async throws -> OAuthToken {
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
            .serializingDecodable(OAuthToken.self)
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
    
    func verifyCredentials() async throws -> UserProfile {
        let url = MastodonEndpoint.verifyCredentials.url(for: account.server.address)
    
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(UserProfile.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func postStatus(_ status: String, visibility: Visibility) async throws -> Status {
        let url = MastodonEndpoint.statuses.url(for: account.server.address)
            
        let response = await AF.request(url, method: .post, parameters: [
            "status": status,
            "visibility": visibility.rawValue
        ], headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func notifications() async throws -> [Notification] {
        let url = MastodonEndpoint.notifications.url(for: account.server.address)
        
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable([Notification].self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func homeTimeline() async throws -> [Status] {
        let url = MastodonEndpoint.homeTimeline.url(for: account.server.address)
        
            
        let response = await AF.request(url, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable([Status].self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func favourite(statusId: String) async throws -> Status {
        let url = MastodonEndpoint.favourite(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func unfavourite(statusId: String) async throws -> Status {
        let url = MastodonEndpoint.unfavourite(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func reblog(statusId: String) async throws -> Status {
        let url = MastodonEndpoint.reblog(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Status.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
    }
    
    func unreblog(statusId: String) async throws -> Status {
        let url = MastodonEndpoint.unreblog(of: statusId).url(for: account.server.address)
        
        let response = await AF.request(url, method: .post, headers: [
            "Authorization": "Bearer \(account.accessToken)"
        ])
            .validate()
            .serializingDecodable(Status.self)
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
