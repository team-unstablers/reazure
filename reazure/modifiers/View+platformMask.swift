//
//  View+platform.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/17/24.
//

import SwiftUI

extension View {
    @ViewBuilder
    func platformMask<Content: View>(_ mask: PlatformMask, @ViewBuilder transform: (Self) -> Content) -> some View {
        if mask.test() {
            transform(self)
        } else {
            self
        }
    }
    
}
