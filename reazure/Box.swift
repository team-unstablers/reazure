//
//  Box.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
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
