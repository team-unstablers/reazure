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
    
    func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

struct CustomEmoji: Codable {
    let shortcode: String
    let url: String
    let static_url: String
}

struct Application: Codable {
    let name: String
}

struct Status: Codable {
    let id: String
    let created_at: String
    
    let visibility: String

    let content: String
    let account: UserProfile
    

    let reblog: Box<Status>?
    
    let emojis: [CustomEmoji]
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
