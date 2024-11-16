//
//  AboutAppHeader.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI


fileprivate struct AboutAppHeaderBackground: View {
    static let backgroundGradient: Gradient = Gradient(colors: [
        Color(hex: 0x0099EA),
        Color(hex: 0x162A9B)
    ])

    var body: some View {
        LinearGradient(gradient: Self.backgroundGradient, startPoint: .top, endPoint: .bottom)
    }
}


struct AboutAppHeader: View {
    let appIcon = Bundle.main.icon
    
    @State
    private var fadeAnimation = false

    var body: some View {
        VStack {
            Image("logo_kari")
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 128)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 4)
                .padding(.bottom, 8)
            
            VStack {
                (Text("PRODUCT_NAME") + Text(" ") + Text("PRODUCT_DISPLAY_VERSION"))
                    .padding(.bottom, 8)
                
                Text("PRODUCT_SLOGAN")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            AboutAppHeaderBackground()
        }
        .fadeIn(.easeIn(duration: 0.5))
    }
}

#Preview {
    AboutAppHeader()
}
