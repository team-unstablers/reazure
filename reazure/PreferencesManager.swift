//
//  PreferencesManager.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//
import Foundation
import CoreGraphics

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published
    var playSoundOnNotification: Bool = true
    
    @Published
    var notificationSound: NotificationSound = .default

    @Published
    var vibrateOnNotification: Bool = true
    
    @Published
    var theme: AppTheme = .default
    
    @Published
    var compactMode: Bool = false

    @Published
    var showExtKeypad: Bool = false
    
    @Published
    var swapJKOnExtKeypad: Bool = false

    @Published
    var alwaysShowSoftwareKeyboard: Bool = false
    
    @Published
    var liftDownPostArea: Bool = false

    @Published
    var respectSystemFontSize: Bool = true

    @Published
    var fontSize: Int = 15


    /// `reazureApp`에서 환경으로 주입하는 폰트 크기 정책.
    var appFontMetrics: AppFontMetrics {
        AppFontMetrics(respectsSystemSize: respectSystemFontSize, baseSize: CGFloat(fontSize))
    }


    init() {
        refresh()
    }
    
    func refresh() {
        let defaults = UserDefaults.standard
        
        self.playSoundOnNotification = defaults.bool(forKey: "playSoundOnNotification")
        self.notificationSound = NotificationSound(rawValue: defaults.string(forKey: "notificationSound") ?? "default") ?? .default
        self.vibrateOnNotification = defaults.bool(forKey: "vibrateOnNotification")
        self.theme = AppTheme.registry[defaults.string(forKey: "theme") ?? "default"] ?? .default
        self.compactMode = defaults.bool(forKey: "compactMode")
        self.showExtKeypad = defaults.bool(forKey: "showExtKeypad")
        self.swapJKOnExtKeypad = defaults.bool(forKey: "swapJKOnExtKeypad")
        self.alwaysShowSoftwareKeyboard = defaults.bool(forKey: "alwaysShowSoftwareKeyboard")
        self.liftDownPostArea = defaults.bool(forKey: "liftDownPostArea")

        // bool(forKey:)/integer(forKey:)는 키가 없을 때 false/0을 돌려주므로,
        // 위 프로퍼티 기본값을 살리려면 부재 여부를 명시적으로 확인해야 한다.
        self.respectSystemFontSize = defaults.object(forKey: "respectSystemFontSize") == nil
            ? true
            : defaults.bool(forKey: "respectSystemFontSize")

        let storedFontSize = defaults.integer(forKey: "fontSize")
        self.fontSize = storedFontSize == 0 ? 15 : min(max(storedFontSize, 12), 22)
    }
    
    func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.playSoundOnNotification, forKey: "playSoundOnNotification")
        defaults.set(self.notificationSound.rawValue, forKey: "notificationSound")
        defaults.set(self.vibrateOnNotification, forKey: "vibrateOnNotification")
        defaults.set(self.theme.id, forKey: "theme")
        defaults.set(self.compactMode, forKey: "compactMode")
        defaults.set(self.showExtKeypad, forKey: "showExtKeypad")
        defaults.set(self.swapJKOnExtKeypad, forKey: "swapJKOnExtKeypad")
        defaults.set(self.alwaysShowSoftwareKeyboard, forKey: "alwaysShowSoftwareKeyboard")
        defaults.set(self.liftDownPostArea, forKey: "liftDownPostArea")
        defaults.set(self.respectSystemFontSize, forKey: "respectSystemFontSize")
        defaults.set(self.fontSize, forKey: "fontSize")
    }
}

