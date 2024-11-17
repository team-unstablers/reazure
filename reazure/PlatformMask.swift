//
//  PlatformMask.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/17/24.
//

import UIKit

struct PlatformMask: RawRepresentable, OptionSet {
    static let current = determineCurrent()
    
    let rawValue: Int
    
    private static func determineCurrent() -> Self {
        let processInfo = ProcessInfo.processInfo
        
        if processInfo.isiOSAppOnMac {
            return .macOS
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPadOS
        }
        
        return .iOS
    }
    
    
    static let iOS = PlatformMask(rawValue: 1 << 0)
    static let macOS = PlatformMask(rawValue: 1 << 1)
    static let iPadOS = PlatformMask(rawValue: 1 << 2)
}

extension PlatformMask {
    func test() -> Bool {
        self.contains(.current)
    }
}
