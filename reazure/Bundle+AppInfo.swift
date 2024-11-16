//
//  Bundle+AppInfo.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import Foundation

import UIKit

extension Bundle {
    public var icons: [UIImage] {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
            return iconFiles.compactMap { UIImage(named: $0) }
        }
            
        return []
    }
    
    public var icon: UIImage? {
        icons.sorted(by: { $0.size.height > $1.size.height }).first
    }
}
