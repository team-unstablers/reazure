//
//  gradientBackground.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import UIKit

/// Azurea-like theme
struct AzureaTheme {
    static let bgGradient: [(UIColor, CGFloat)] = [
        (.init(r8: 112, g8: 156, b8: 217), 0),
        (.init(r8: 50,  g8: 102, b8: 163), 0.49),
        (.init(r8: 10,  g8: 53,  b8: 121), 0.5),
        (.init(r8: 10,  g8: 53,  b8: 129), 1),
    ]
}

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

func generateGradientBackground(colors: [(UIColor, CGFloat)], height: CGFloat = 56) -> UIImage {
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = CGRect(x: 0, y: 0, width: 1, height: height)
    
    gradientLayer.colors = colors.map { $0.0.cgColor }
    gradientLayer.locations = colors.map { $0.1 as NSNumber }
    
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    
    let renderer = UIGraphicsImageRenderer(size: gradientLayer.frame.size)
    return renderer.image { context in
        gradientLayer.render(in: context.cgContext)
    }
}


