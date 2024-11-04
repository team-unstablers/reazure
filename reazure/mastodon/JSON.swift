//
// Created by Gyuhwan Park on 5/7/24.
//

import Foundation

public struct JSONEncDec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init(
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
    ) {
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = keyEncodingStrategy
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = keyDecodingStrategy
    }
    
    public func stringify<T: Encodable>(
        _ value: T
    ) throws -> String {
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }

    public func parse<T: Decodable>(
        _ jsonString: String,
        to type: T.Type
    ) throws -> T {
        let data = jsonString.data(using: .utf8)!
        return try decoder.decode(type, from: data)
    }
    
    public func parseAsDictionary(
        _ jsonString: String
    ) throws -> Dictionary<String, Any> {
        let data = jsonString.data(using: .utf8)!
        
        return try JSONSerialization.jsonObject(with: data, options: []) as! Dictionary<String, Any>
    }
}

public let JSON = JSONEncDec(
    keyEncodingStrategy: .convertToSnakeCase,
    keyDecodingStrategy: .convertFromSnakeCase
)
