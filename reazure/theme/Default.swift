//
//  Default.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

import SwiftUI

extension AppTheme {
    static let `default` = AppTheme(
        id: "default",
        
        name: "re;azure",
        author: "team unstablers Inc.",
        
        light: AppPalette(
            shell32Background: .init(r8: 235, g8: 235, b8: 235),
            shell32Foreground: .primary,
            
            navbarBackground: Gradient(stops: [
                .init(color: .init(r8: 112, g8: 156, b8: 217), location: 0),
                .init(color: .init(r8: 50,  g8: 102, b8: 163), location: 0.49),
                .init(color: .init(r8: 10,  g8: 53,  b8: 121), location: 0.5),
                .init(color: .init(r8: 10,  g8: 53,  b8: 129), location: 1),
            ]),
            navbarForeground: .white,
            
            timelineBackground: .white,
            
            postItemNormalBackground: .white,
            postItemRebloggedBackground: .init(r8: 135, g8: 245, b8: 66, a: 0.2),
            postItemFavouritedBackground: .init(r8: 245, g8: 239, b8: 66, a: 0.2),
            postItemFocusedBackground: .init(r8: 66, g8: 203, b8: 245, a: 0.2),
            
            postItemNormalForeground: .primary,
            postItemMentionForeground: .init(r8: 66, g8: 78, b8: 245, a: 1.0),
            
            postItemBorder: .gray
        ),
        
        dark: AppPalette(
            shell32Background: .init(r8: 235, g8: 235, b8: 235),
            shell32Foreground: .primary,
            
            navbarBackground: Gradient(stops: [
                .init(color: .init(r8: 112, g8: 156, b8: 217), location: 0),
                .init(color: .init(r8: 50,  g8: 102, b8: 163), location: 0.49),
                .init(color: .init(r8: 10,  g8: 53,  b8: 121), location: 0.5),
                .init(color: .init(r8: 10,  g8: 53,  b8: 129), location: 1),
            ]),
            navbarForeground: .white,
            
            timelineBackground: .black,
            
            postItemNormalBackground: .black,
            postItemRebloggedBackground: .init(r8: 135, g8: 245, b8: 66, a: 0.2),
            postItemFavouritedBackground: .init(r8: 245, g8: 239, b8: 66, a: 0.2),
            postItemFocusedBackground: .init(r8: 66, g8: 203, b8: 245, a: 0.2),
            
            postItemNormalForeground: .primary,
            postItemMentionForeground: .init(r8: 66, g8: 78, b8: 245, a: 1.0),
            
            postItemBorder: .gray
        )
    )
}
