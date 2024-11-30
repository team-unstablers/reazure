//
//  AzureaSakura.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import SwiftUI

extension AppTheme {
    static let `azureaSakura` = AppTheme(
        id: "AzureaSakura",
        
        name: "Sakura (Azurea, experimental)",
        author: "tmyt",
        
        light: AppPalette(
            shell32Background: .init(r8: 235, g8: 235, b8: 235),
            shell32Foreground: .primary,
            
            navbarBackground: Gradient(stops: [
                .init(color: .init(hex: 0xEFC1EE), location: 0),
                .init(color: .init(hex: 0xDB5DAF), location: 0.49),
                .init(color: .init(hex: 0xBA3F61), location: 0.5),
                .init(color: .init(hex: 0xBA3F61), location: 1),
            ]),
            navbarForeground: .white,
            
            extKeypadBackground: .init(r8: 209, g8: 212, b8: 217),
            extKeypadButtonBackground: .white,
            extKeypadButtonForeground: .black,
            extKeypadButtonSecondaryForeground: .gray,
            
            timelineBackground: .white,
            
            postItemNormalBackground: .init(hex: 0xFFE0E0),
            
            // FIXME: reblogged와 favourite 색상 설정해야 함
            postItemRebloggedBackground: .init(r8: 135, g8: 245, b8: 66, a: 0.2),
            postItemFavouritedBackground: .init(r8: 245, g8: 239, b8: 66, a: 0.2),
            postItemFocusedBackground: .init(hex: 0xD0E0FF),
            
            postItemNormalForeground: .init(hex: 0x403000),
            postItemMentionForeground: .init(hex: 0x0000FF),
            
            postItemBorder: .gray
        ),
        
        dark: AppPalette(
            shell32Background: .init(r8: 235, g8: 235, b8: 235),
            shell32Foreground: .primary,
            
            navbarBackground: Gradient(stops: [
                .init(color: .init(hex: 0xEFC1EE), location: 0),
                .init(color: .init(hex: 0xDB5DAF), location: 0.49),
                .init(color: .init(hex: 0xBA3F61), location: 0.5),
                .init(color: .init(hex: 0xBA3F61), location: 1),
            ]),
            navbarForeground: .white,
            
            extKeypadBackground: .init(r8: 209, g8: 212, b8: 217),
            extKeypadButtonBackground: .white,
            extKeypadButtonForeground: .black,
            extKeypadButtonSecondaryForeground: .gray,
            
            timelineBackground: .white,
            
            postItemNormalBackground: .init(hex: 0xFFE0E0),
            
            // FIXME: reblogged와 favourite 색상 설정해야 함
            postItemRebloggedBackground: .init(r8: 135, g8: 245, b8: 66, a: 0.2),
            postItemFavouritedBackground: .init(r8: 245, g8: 239, b8: 66, a: 0.2),
            postItemFocusedBackground: .init(hex: 0xD0E0FF),
            
            postItemNormalForeground: .init(hex: 0x403000),
            postItemMentionForeground: .init(hex: 0x0000FF),
            
            postItemBorder: .gray
        )
    )
}
