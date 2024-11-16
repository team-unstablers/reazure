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


