//
//  ContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/11/24.
//
import SwiftUI

struct ContextMenu<T>: View where T: View {
    var content: () -> T
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(16)
        .background(AzureaTheme.win32Background.shadow(radius: 2, x: 2, y: 2))
        .border(.gray, width: 1)
    }
}

#Preview {
    VStack {
        ContextMenu {
            Group {
                Text("Hello, World!")
                Text("Hello, World!")
                Text("Hello, World!")
            }
        }
    }
    .padding()
}
