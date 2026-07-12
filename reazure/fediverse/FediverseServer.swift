//
//  FediverseServer.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//


enum FediverseServer: Codable {
    case mastodon(address: String)
    case misskey(address: String)
    
    var address: String {
        switch self {
        case .mastodon(let address):
            return address
        case .misskey(let address):
            return address
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case serverSoftware
        case address
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let serverSoftware = try container.decode(String.self, forKey: .serverSoftware)
        
        switch serverSoftware {
        case "mastodon":
            let address = try container.decode(String.self, forKey: .address)
            self = .mastodon(address: address)
        case "misskey":
            let address = try container.decode(String.self, forKey: .address)
            self = .misskey(address: address)
        default:
            throw DecodingError.dataCorruptedError(forKey: .serverSoftware, in: container, debugDescription: "Unknown server software")
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .mastodon(let address):
            try container.encode("mastodon", forKey: .serverSoftware)
            try container.encode(address, forKey: .address)
            
        case .misskey(let address):
            try container.encode("misskey", forKey: .serverSoftware)
            try container.encode(address, forKey: .address)
        }
    }
    
    func configuration() async throws -> FediverseServerConfiguration {
        switch self {
        case .mastodon(let address):
            let instance = try await MastodonClient.instanceInfo(of: address)
            return instance.configuration.asCompatibleConfiguration()
        case .misskey(let address):
            let meta = try await MisskeyClient.meta(of: address)
            // Misskey streams over the same host (wss://<host>/streaming), so the
            // streaming endpoint is just the address.
            return FediverseServerConfiguration(streamingEndpoint: address,
                                                maxPostLength: meta.maxNoteTextLength ?? 3000)
        }
    }

    /// Builds the REST client for this server kind. The single per-server switch
    /// that keeps `SessionManager` and the action performer server-agnostic.
    func makeClient(for account: Account) -> any FediverseClient {
        switch self {
        case .mastodon:
            return MastodonClient(using: account)
        case .misskey:
            return MisskeyClient(using: account)
        }
    }

    /// The streaming protocol strategy (URL / on-connect / frame translation) for
    /// this server kind, injected into the shared `StreamingClient`.
    func streamingAdapter(for account: Account) -> StreamingProtocolAdapter {
        switch self {
        case .mastodon:
            return MastodonStreamingAdapter()
        case .misskey:
            return MisskeyStreamingAdapter()
        }
    }

    /// The payload decode seam for this server's streaming events. Selecting the
    /// decoder here keeps `SharedClient` unaware of the server kind. Misskey's
    /// streaming *envelope* is normalized to the shared `{event, payload}` shape by
    /// `MisskeyStreamingAdapter`, so the same `EventIngestor` demux drives both.
    func streamingEventDecoder() -> StreamingEventDecoder {
        switch self {
        case .mastodon:
            return MastodonEventDecoder()
        case .misskey:
            return MisskeyEventDecoder()
        }
    }
}

struct FediverseServerConfiguration {
    let streamingEndpoint: String
    let maxPostLength: Int
}

extension FediverseServer: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .mastodon(let address):
            hasher.combine("mastodon")
            hasher.combine(address)
        case .misskey(let address):
            hasher.combine("misskey")
            hasher.combine(address)
        }
    }
    
    static func ==(lhs: FediverseServer, rhs: FediverseServer) -> Bool {
        switch (lhs, rhs) {
        case (.mastodon(let lhsAddress), .mastodon(let rhsAddress)):
            return lhsAddress == rhsAddress
        case (.misskey(let lhsAddress), .misskey(let rhsAddress)):
            return lhsAddress == rhsAddress
        default:
            return false
        }
        
    }
}


