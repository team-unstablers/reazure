//
//  AppTheme.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

import SwiftUI
import UIKit

struct AppPalette {
    var shell32Background: Color
    var shell32Foreground: Color
    
    var navbarBackground: Gradient
    var navbarForeground: Color
    
    var timelineBackground: Color
    
    var postItemNormalBackground: Color
    var postItemRebloggedBackground: Color
    var postItemFavouritedBackground: Color
    var postItemFocusedBackground: Color
    
    var postItemNormalForeground: Color
    var postItemMentionForeground: Color

    var postItemBorder: Color
}

struct AppTheme: Identifiable, Hashable {
    var id: String
    
    var name: String
    var author: String
    
    var light: AppPalette
    var dark: AppPalette
    
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AppTheme {
    static let registry: [String: AppTheme] = [
        "default": .default
    ]
    
    // 게으르다 게을러.. ㅠㅠ
    static let allCases: [AppTheme] = [
        .default
    ]
}
