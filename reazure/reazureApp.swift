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
    private var preferencesManager = PreferencesManager.shared
    
    @StateObject
    private var accountManager = AccountManager()
    
    @StateObject
    private var sharedClient = SharedClient.shared

    @UIApplicationDelegateAdaptor
    private var appDelegate: AppDelegate

    @Environment(\.scenePhase)
    private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(preferencesManager)
                .environmentObject(accountManager)
                .environmentObject(sharedClient)
                .environment(\.appTheme, preferencesManager.theme)
                .onChange(of: scenePhase) { _, newPhase in
                    // Streaming sockets die while suspended; reconnect on return to
                    // the foreground so the timeline resumes without waiting on the
                    // backoff (or after it has given up).
                    if newPhase == .active {
                        sharedClient.reconnectStreamingIfNeeded()
                    }
                }
        }
    }
}
