//
//  ContentView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct AppRootView: View {
    enum AppRootNavState {
        case signin
    }
    
    @Environment(\.palette)
    var palette: AppPalette
    
    @FocusState
    var focused: Bool
    
    @EnvironmentObject
    var preferencesManager: PreferencesManager

    @EnvironmentObject
    var accountManager: AccountManager
    
    @EnvironmentObject
    var sharedClient: SharedClient
 
    @State
    var navState: [AppRootNavState] = []
    
    @State
    var text: String = "Hello, World!"
    
    var postArea: some View {
        PostArea { request in
            Task {
                do {
                    let _ = try await sharedClient.client?.postStatus(request.content, visibility: request.visibility, replyTo: request.replyTo)
                } catch {
                    print(error)
                }
            }
        }
        .zIndex(100)
    }
    
    init() {
        UITabBar.appearance().unselectedItemTintColor = .white
    }
    
    var body: some View {
        NavigationStack(path: $navState) {
            VStack(spacing: 0) {
                if !preferencesManager.liftDownPostArea {
                    postArea
                }
                TabView(selection: $sharedClient.currentTab) {
                    Group {
                        TimelineView(type: .home, timeline: sharedClient.timeline[.home]!)
                            .tag(Tab.home)
                        TimelineView(type: .notifications, timeline: sharedClient.timeline[.notifications]!)
                            .tag(Tab.notification)
                        VStack {
                            Spacer()
                            Text("IN CONSTRUCTION")
                            Spacer()
                        }
                            .tag(Tab.profile)
                        AboutAppView {
                            navState.append(.signin)
                        }
                        .tag(Tab.settings)
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
                
                if preferencesManager.liftDownPostArea {
                    postArea
                }

                Navbar(tabSelection: $sharedClient.currentTab) { tab in
                    sharedClient.currentTab = tab
                }
                
                if preferencesManager.showExtKeypad {
                    ExtKeypad()
                }
                
                ShortcutHandler()
                    .frame(width: 0, height: 0)
            }
            .background(palette.shell32Background)
            .watchAccountManager {
                navState.append(.signin)
            }
            .navigationDestination(for: AppRootNavState.self) { navState in
                if (navState == .signin) {
                    AddAccountView {
                        self.navState.removeAll()
                    }
                        .environmentObject(accountManager)
                }
            }
        }
    }
        
}

#Preview {
    AppRootView()
        .environmentObject(AccountManager())
        .environmentObject(SharedClient.shared)
        .environmentObject(PreferencesManager())
}
