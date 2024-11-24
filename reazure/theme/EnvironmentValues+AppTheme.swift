//
//  EnvironmentValues+palette.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

import SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
    
    var palette: AppPalette {
        let colorScheme = self.colorScheme
        
        if colorScheme == .light {
            return appTheme.light
        } else {
            return appTheme.dark
        }
    }
    
}
