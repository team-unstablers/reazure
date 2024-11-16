//
//  View+fadeIn.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI

extension View {
    func fadeIn(_ animation: Animation = .easeIn(duration: 0.3)) -> some View {
        self.modifier(FadeInModifier(animation: animation))
    }
}

struct FadeInModifier: ViewModifier {
    let animation: Animation
    
    @State
    private var isAnimated: Bool = false
    
    func body(content: Content) -> some View {
        content.opacity(isAnimated ? 1 : 0)
            .onAppear {
                withAnimation(animation) {
                    isAnimated = true
                }
            }
    }
}
