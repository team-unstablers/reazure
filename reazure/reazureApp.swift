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
                .environment(\.appFontMetrics, preferencesManager.appFontMetrics)
                // OFF일 때만 폰트 미지정 텍스트를 고정 pt로 덮고, 직접 손대지
                // 못하는 시스템 크롬(네비 타이틀, Picker 메뉴 등)까지 100% 배율로
                // 고정한다. ON일 때는 아무 것도 적용하지 않아 현재 동작(Dynamic
                // Type 및 Section footer 등 SwiftUI 기본 텍스트 스타일)을 그대로
                // 유지한다.
                .if(!preferencesManager.respectSystemFontSize) {
                    $0
                        .environment(\.font, .system(size: CGFloat(preferencesManager.fontSize)))
                        .dynamicTypeSize(.large ... .large)
                }
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
