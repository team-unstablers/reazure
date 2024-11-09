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
    
    enum Tab {
        case home
        case notification
        case profile
        case settings
    }
    
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
    
    @State
    var tabSelection: Tab = .home
   
    init() {
        UITabBar.appearance().unselectedItemTintColor = .white
    }
    
    var body: some View {
        NavigationStack(path: $navState) {
            VStack(spacing: 0) {
                PostArea { request in
                    print(request)
                }
                TabView(selection: $tabSelection) {
                    Group {
                        TimelineView(type: .home)
                            .tag(Tab.home)
                        TimelineView(type: .local)
                            .tag(Tab.notification)
                        TimelineView(type: .federated)
                            .tag(Tab.profile)
                        AboutAppView {
                            navState.append(.signin)
                        }
                            .tag(Tab.settings)
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
                Navbar(tabSelection: $tabSelection) { tab in
                    tabSelection = tab
                }
                
                if preferencesManager.showExtKeypad {
                    ExtKeypad()
                }
            }
            .background(AzureaTheme.win32Background)
            .watchAccountManager {
                navState.append(.signin)
            }
            .navigationDestination(for: AppRootNavState.self) { navState in
                if (navState == .signin) {
                    AddAccountView()
                        .environmentObject(accountManager)
                }
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AccountManager())
        .environmentObject(SharedClient())
}
