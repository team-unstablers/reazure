//
//  PreferencesManager.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//
import Foundation

class PreferencesManager: ObservableObject {
    
    @Published
    var showExtKeypad: Bool = false {
        didSet {
            save()
        }
    }
    
    @Published
    var alwaysShowSoftwareKeyboard: Bool = false {
        didSet {
            save()
        }
    }
    
    init() {
        refresh()
    }
    
    func refresh() {
        let defaults = UserDefaults.standard
        
        self.showExtKeypad = defaults.bool(forKey: "showExtKeypad")
        self.alwaysShowSoftwareKeyboard = defaults.bool(forKey: "alwaysShowSoftwareKeyboard")
    }
    
    func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.showExtKeypad, forKey: "showExtKeypad")
        defaults.set(self.alwaysShowSoftwareKeyboard, forKey: "alwaysShowSoftwareKeyboard")
    }
}
