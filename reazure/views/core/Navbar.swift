//
//  Navbar.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct Navbar: View {
    @Environment(\.palette)
    var palette: AppPalette
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @Binding
    var tabSelection: Tab

    var tabChange: (Tab) -> Void
    
    
    var body: some View {
        HStack {
            Group {
                Button {
                    tabChange(.home)
                } label: {
                    Text(Image(systemName: "house"))
                        .font(.system(size: 20))
                        .foregroundStyle(palette.navbarForeground)
                }
                .shadow(color: palette.navbarForeground, radius: tabSelection == .home ? 4 : 0)
                .conditionalShortcut("1", modifiers: [], when: !sharedClient.postAreaFocused)
                
                Spacer()
                
                Button {
                    tabChange(.notification)
                } label: {
                    Text(Image(systemName: "at"))
                        .font(.system(size: 20))
                        .foregroundStyle(palette.navbarForeground)
                        .overlay {
                            if sharedClient.unreadNotificationCount > 0 {
                                Text(verbatim: String(sharedClient.unreadNotificationCount))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 10, y: -10)
                            }
                        }
                }
                .shadow(color: palette.navbarForeground, radius: tabSelection == .notification ? 4 : 0)
                .conditionalShortcut("2", modifiers: [], when: !sharedClient.postAreaFocused)

                Spacer()
                
                Button {
                    tabChange(.profile)
                } label: {
                    Text(Image(systemName: "globe"))
                        .font(.system(size: 20))
                        .foregroundStyle(palette.navbarForeground)
                }
                .shadow(color: palette.navbarForeground, radius: tabSelection == .profile ? 4 : 0)
                .conditionalShortcut("3", modifiers: [], when: !sharedClient.postAreaFocused)

                Spacer()
                
                Button {
                    tabChange(.settings)
                } label: {
                    Text(Image(systemName: "gear"))
                        .font(.system(size: 20))
                        .foregroundStyle(palette.navbarForeground)
                }
                .shadow(color: palette.navbarForeground, radius: tabSelection == .settings ? 4 : 0)
                .conditionalShortcut("4", modifiers: [], when: !sharedClient.postAreaFocused)

            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 32)
        .frame(height: 48)
        .background(
            LinearGradient(gradient: palette.navbarBackground, startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    let sharedClient = SharedClient.shared
    
    Navbar(tabSelection: .constant(.home)) { _ in
        
    }
    .environmentObject(sharedClient)
    .onAppear {
        sharedClient.unreadNotificationCount = 42
    }
}

fileprivate extension View {
    
}
