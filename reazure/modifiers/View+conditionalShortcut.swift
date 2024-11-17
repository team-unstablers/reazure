//
//  View+conditionalShortcut.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/17/24.
//

import SwiftUI

extension View {
    func conditionalShortcut(_ shortcut: KeyEquivalent, modifiers: EventModifiers, when condition: Bool) -> some View {
        if condition {
            return AnyView(self.keyboardShortcut(shortcut, modifiers: modifiers))
        } else {
            return AnyView(self)
        }
    }
}
