//
//  Color+fromRGB.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
    
    convenience init(r8: Int, g8: Int, b8: Int, a: CGFloat = 1.0) {
        self.init(
            red: CGFloat(r8) / 255.0,
            green: CGFloat(g8) / 255.0,
            blue: CGFloat(b8) / 255.0,
            alpha: a
        )
    }
}

extension Color {
    init(hex: Int, alpha: CGFloat = 1.0) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }
    
    init(r8: Int, g8: Int, b8: Int, a: CGFloat = 1.0) {
        self.init(uiColor: UIColor(r8: r8, g8: g8, b8: b8, a: a))
    }
}
