//
//  AboutAppHeader.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI


fileprivate struct AboutAppFooterBackground: View {
    static let backgroundGradient: Gradient = Gradient(colors: [
        Color(hex: 0xF2EC2A),
        Color(hex: 0xFF9500)
    ])

    var body: some View {
        LinearGradient(gradient: Self.backgroundGradient, startPoint: .top, endPoint: .bottom)
    }
}


struct AboutAppFooter: View {
    var body: some View {
        VStack(alignment: .leading) {
            (Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(" ") + Text("ABOUT_APP_FOOTER_NOTICE_TITLE"))
                .bold()
                .foregroundStyle(.black.opacity(0.9))
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            Text("ABOUT_APP_FOOTER_NOTICE_CONTENT")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.8))
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            
            Group {
                Text("")
                Text("ABOUT_APP_FOOTER_NOTICE_CONTENT_FOOTER")
            }
                .font(.caption2)
                .italic()
                .foregroundStyle(.black.opacity(0.8))
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            AboutAppFooterBackground()
        }
    }
}

#Preview {
    AboutAppFooter()
}
