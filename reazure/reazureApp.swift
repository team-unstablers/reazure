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

    /// Whether the app has been in the background since the last resume. Tracked as
    /// a flag rather than read from `onChange`'s `oldPhase`, because a resume
    /// arrives as `.background → .inactive → .active`: by the time `.active` lands,
    /// the previous phase is `.inactive`, and comparing against `.background` there
    /// would never match.
    @State
    private var wasBackgrounded = false

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
                    // Streaming sockets die while suspended, and the stream never
                    // replays what it missed — so a return from the background both
                    // reconnects (without waiting on the backoff, or after it has
                    // given up) and backfills the timelines over REST.
                    //
                    // Gated on an actual background round-trip: `.active` alone fires
                    // for notification banners, the app switcher, Control Center and
                    // iPad split-view resizes, none of which drop the stream, and
                    // refreshing on each would be pure churn.
                    switch newPhase {
                    case .background:
                        wasBackgrounded = true
                    case .active:
                        if wasBackgrounded {
                            wasBackgrounded = false
                            sharedClient.resumeFromBackground()
                        }
                    default:
                        break
                    }
                }
        }

        // 첨부 이미지 뷰어 전용 윈도우. iPad/macOS에서 `openWindow(value:)`로 열리며,
        // iPhone에서는 멀티 씬을 지원하지 않으므로 사용되지 않는다(대신 fullScreenCover).
        WindowGroup(for: AttachmentGalleryContext.self) { $context in
            if let context {
                AttachmentGalleryView(context: context)
                    .environmentObject(preferencesManager)
                    .environment(\.appTheme, preferencesManager.theme)
            }
        }
    }
}
