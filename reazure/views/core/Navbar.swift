//
//  Navbar.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct Navbar: View {
    
    @Binding
    var tabSelection: AppRootView.Tab
    var tabChange: (AppRootView.Tab) -> Void
    
    var body: some View {
        HStack {
            Group {
                Button {
                    tabChange(.home)
                } label: {
                    Image(systemName: "house")
                }
                .shadow(color: .white, radius: tabSelection == .home ? 4 : 0)
                
                Spacer()
                
                Button {
                    tabChange(.notification)
                } label: {
                    Image(systemName: "house")
                }
                .shadow(color: .white, radius: tabSelection == .notification ? 4 : 0)

                Spacer()
                
                Button {
                    tabChange(.profile)
                } label: {
                    Image(systemName: "globe")
                }
                .shadow(color: .white, radius: tabSelection == .profile ? 4 : 0)

                Spacer()
                
                Button {
                    tabChange(.settings)
                } label: {
                    Image(systemName: "globe")
                }
                .shadow(color: .white, radius: tabSelection == .settings ? 4 : 0)

            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 32)
        .frame(height: 48)
        .background(
            Image(uiImage: generateGradientBackground(colors: AzureaTheme.bgGradient))
                .resizable()
        )
    }
}

#Preview {
    Navbar(tabSelection: .constant(.home)) { _ in
        
    }
}

fileprivate extension View {
    
}
