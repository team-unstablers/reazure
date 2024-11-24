//
//  PreferencesManager.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//
import Foundation

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
    }
}

