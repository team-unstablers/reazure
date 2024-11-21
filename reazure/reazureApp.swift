//
//  reazureApp.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

let PRODUCT_VERSION = "1.0.1.1"

@main
struct reazureApp: App {
    
    @StateObject
    private var preferencesManager = PreferencesManager.shared
    
    @StateObject
    private var accountManager = AccountManager()
    
    @StateObject
    private var sharedClient = SharedClient()

    @UIApplicationDelegateAdaptor
    private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(preferencesManager)
                .environmentObject(accountManager)
                .environmentObject(sharedClient)
        }
    }
}
