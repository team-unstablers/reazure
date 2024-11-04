//
//  reazureApp.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

@main
struct reazureApp: App {
    
    @StateObject
    private var accountManager = AccountManager()
    
    @StateObject
    private var sharedClient = SharedClient()

    @UIApplicationDelegateAdaptor
    private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(accountManager)
                .environmentObject(sharedClient)
        }
    }
}
