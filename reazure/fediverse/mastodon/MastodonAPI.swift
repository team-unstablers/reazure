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
    static let instance = MastodonEndpoint(rawValue: "/api/v2/instance")
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
    static func defaultScope(for version: String) -> [String] {
        let version = version.split(separator: ".")
        guard let major = Int(version[0]),
              let minor = Int(version[1])
        else {
            return ["read", "write", "profile"]
        }
        
        if (major == 4 && minor <= 2) || major < 4 {
            return ["read", "write"]
        }
        
        return ["read", "write", "profile"]
    }
    
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
    
    static func instanceInfo(of server: String) async throws -> Mastodon.Instance {
        let url = MastodonEndpoint.instance.url(for: server)
        let response = await AF.request(url)
            .validate()
            .serializingDecodable(Mastodon.Instance.self)
            .response
        
        guard let value = response.value else {
            throw response.error!
        }
        
        return value
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
    
    func request<Response>(
        to endpoint: MastodonEndpoint,
        expects type: Response.Type,
        method: HTTPMethod = .get,
        parameters: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> Response where Response: Decodable & Sendable {
        let url = endpoint.url(for: account.server.address)
        
        let headers: HTTPHeaders? = (requiresAuth) ? [
            "Authorization": "Bearer \(account.accessToken)"
        ] : nil
        
        
        let response = await AF.request(url,
                                        method: method,
                                        parameters: parameters,
                                        headers: headers)
            .validate()
            .serializingDecodable(type)
            .response
        
        guard let value = response.value else {
            let error = response.error!
            let underlyingError = error.underlyingError
            
            if underlyingError is DecodingError {
                throw FediverseAPIError.decodingError(originError: underlyingError as! DecodingError)
            }
            
            throw FediverseAPIError.serverError(originError: error)
        }
        
        return value
    }
    
    func verifyCredentials() async throws -> Mastodon.UserProfile {
        return try await request(to: MastodonEndpoint.verifyCredentials,
                                 expects: Mastodon.UserProfile.self)
    }
    
    func status(of statusId: String) async throws -> Mastodon.Status {
        return try await request(to: MastodonEndpoint.status(of: statusId),
                                 expects: Mastodon.Status.self)
    }
    
    func postStatus(_ status: String, visibility: Mastodon.Visibility, replyTo: String? = nil) async throws -> Mastodon.Status {
        var parameters = [
            "status": status,
            "visibility": visibility.rawValue
        ]
        
        if let replyTo = replyTo {
            parameters["in_reply_to_id"] = replyTo
        }

        
        return try await request(to: MastodonEndpoint.statuses,
                                 expects: Mastodon.Status.self,
                                 method: .post,
                                 parameters: parameters)
    }
    
    func notifications() async throws -> [Mastodon.Notification] {
        return try await request(to: MastodonEndpoint.notifications,
                                 expects: [Mastodon.Notification].self)
    }
    
    func homeTimeline() async throws -> [Mastodon.Status] {
        return try await request(to: MastodonEndpoint.homeTimeline,
                                 expects: [Mastodon.Status].self)
    }
    
    func favourite(statusId: String) async throws -> Mastodon.Status {
        return try await request(to: MastodonEndpoint.favourite(of: statusId),
                                 expects: Mastodon.Status.self,
                                 method: .post)
    }
    
    func unfavourite(statusId: String) async throws -> Mastodon.Status {
        return try await request(to: MastodonEndpoint.unfavourite(of: statusId),
                                 expects: Mastodon.Status.self,
                                 method: .post)
    }
    
    func reblog(statusId: String) async throws -> Mastodon.Status {
        return try await request(to: MastodonEndpoint.reblog(of: statusId),
                                 expects: Mastodon.Status.self,
                                 method: .post)
    }
    
    func unreblog(statusId: String) async throws -> Mastodon.Status {
        return try await request(to: MastodonEndpoint.unreblog(of: statusId),
                                 expects: Mastodon.Status.self,
                                 method: .post)
    }
}

fileprivate extension String {
    func sanitizeServerAddress() -> String {
        var server = self
        if server.hasPrefix("https://") {
            server.removeFirst("https://".count)
        } else if server.hasPrefix("http://") {
            server.removeFirst("http://".count)
        } else if server.hasPrefix("wss://") {
            server.removeFirst("wss://".count)
        } else if server.hasPrefix("ws://") {
            server.removeFirst("ws://".count)
        }
        
        if server.hasSuffix("/") {
            server.removeLast()
        }
        
        return server
    }
}
