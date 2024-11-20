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
    var vibrateOnNotification: Bool = true
    
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
        
        self.vibrateOnNotification = defaults.bool(forKey: "vibrateOnNotification")
        self.compactMode = defaults.bool(forKey: "compactMode")
        self.showExtKeypad = defaults.bool(forKey: "showExtKeypad")
        self.swapJKOnExtKeypad = defaults.bool(forKey: "swapJKOnExtKeypad")
        self.alwaysShowSoftwareKeyboard = defaults.bool(forKey: "alwaysShowSoftwareKeyboard")
        self.liftDownPostArea = defaults.bool(forKey: "liftDownPostArea")
    }
    
    func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.vibrateOnNotification, forKey: "vibrateOnNotification")
        defaults.set(self.compactMode, forKey: "compactMode")
        defaults.set(self.showExtKeypad, forKey: "showExtKeypad")
        defaults.set(self.swapJKOnExtKeypad, forKey: "swapJKOnExtKeypad")
        defaults.set(self.alwaysShowSoftwareKeyboard, forKey: "alwaysShowSoftwareKeyboard")
        defaults.set(self.liftDownPostArea, forKey: "liftDownPostArea")
    }
}

