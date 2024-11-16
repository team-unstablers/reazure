//
//  gradientBackground.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI
import UIKit

/// Azurea-like theme
struct AzureaTheme {
    static let win32Background = Color(uiColor: .init(r8: 235, g8: 235, b8: 235))
    
    static let bgGradient: [(UIColor, CGFloat)] = [
        (.init(r8: 112, g8: 156, b8: 217), 0),
        (.init(r8: 50,  g8: 102, b8: 163), 0.49),
        (.init(r8: 10,  g8: 53,  b8: 121), 0.5),
        (.init(r8: 10,  g8: 53,  b8: 129), 1),
    ]
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

typealias RAGradientPair = (Color, CGFloat)
typealias RAGradientDefinition = Array<RAGradientPair>

extension RAGradientDefinition {
    func asGradient(_ height: CGFloat) -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 1, height: height)
        
        gradientLayer.colors = self.map { $0.0.cgColor! }
        gradientLayer.locations = self.map { $0.1 as NSNumber }
        
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        
        let renderer = UIGraphicsImageRenderer(size: gradientLayer.frame.size)
        return renderer.image { context in
            gradientLayer.render(in: context.cgContext)
        }
    }
}
