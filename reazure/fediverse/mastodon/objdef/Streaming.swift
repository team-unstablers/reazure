//
//  Streaming.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//

extension Mastodon {
    struct StreamingEvent: Codable {
        let event: String
        let payload: String?
    }
}
