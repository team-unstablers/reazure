//
//  Status.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

class Box<T: Codable>: Codable {
    let wrappedValue: T
    
    required init(from decoder: Decoder) throws {
        wrappedValue = try T(from: decoder)
    }
    
    init(_ value: T) {
        self.wrappedValue = value
    }
    
    func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

struct Visibility: RawRepresentable, Codable, Equatable, Hashable {
    var rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    static let publicType = Visibility(rawValue: "public")
    static let unlisted = Visibility(rawValue: "unlisted")
    static let privateType = Visibility(rawValue: "private")
    static let direct = Visibility(rawValue: "direct")
}

struct CustomEmoji: Codable {
    let shortcode: String
    let url: String
    let static_url: String
}

struct Application: Codable {
    let name: String
}

struct Mention: Codable {
    let id: String
    let username: String
    let acct: String
}

struct Status: Codable {
    let id: String
    let created_at: String
    
    let visibility: String

    let content: String
    let account: UserProfile
    

    let reblog: Box<Status>?
    
    let emojis: [CustomEmoji]
    let mentions: [Mention]
    
    let application: Application?
}


extension Status: Hashable, Equatable, Identifiable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Status {
    func mentions(id: String) -> Bool {
        return mentions.contains(where: { $0.id == id })
    }
}
