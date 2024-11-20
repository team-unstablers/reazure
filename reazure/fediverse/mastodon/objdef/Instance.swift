//
//  Instance.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/20/24.
//

extension Mastodon {
    struct InstanceURLsConfiguration: Codable {
        let streaming: String
    }
    
    struct InstanceStatusesConfiguration: Codable {
        let max_characters: Int
    }
    
    struct InstanceConfiguration: Codable {
        let urls: InstanceURLsConfiguration
        let statuses: InstanceStatusesConfiguration
    }
    
    struct Instance: Codable {
        let configuration: InstanceConfiguration
    }
}


extension Mastodon.InstanceConfiguration {
    func asCompatibleConfiguration() -> FediverseServerConfiguration {
        return FediverseServerConfiguration(
            streamingEndpoint: self.urls.streaming,
            maxPostLength: self.statuses.max_characters
        )
    }
}
