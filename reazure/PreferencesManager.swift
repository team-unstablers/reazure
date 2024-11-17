//
//  PreferencesManager.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//
import Foundation

class PreferencesManager: ObservableObject {
    
    @Published
    var showExtKeypad: Bool = false
    @Published
    var alwaysShowSoftwareKeyboard: Bool = false
    @Published
    var liftDownPostArea: Bool = false
    
    
    init() {
        refresh()
    }
    
    func refresh() {
        let defaults = UserDefaults.standard
        
        self.showExtKeypad = defaults.bool(forKey: "showExtKeypad")
        self.alwaysShowSoftwareKeyboard = defaults.bool(forKey: "alwaysShowSoftwareKeyboard")
        self.liftDownPostArea = defaults.bool(forKey: "liftDownPostArea")
    }
    
    func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.showExtKeypad, forKey: "showExtKeypad")
        defaults.set(self.alwaysShowSoftwareKeyboard, forKey: "alwaysShowSoftwareKeyboard")
        defaults.set(self.liftDownPostArea, forKey: "liftDownPostArea")
    }
}

