//
//  View+handlesShortcut.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/12/24.
//

import SwiftUI

extension View {
    func setupShortcutHandler(with sharedClient: SharedClient) -> some View {
        func handler(for key: ShortcutKey) -> (() -> KeyPress.Result) {
            return {
                sharedClient.handleShortcut(key: key)
                
                return .handled
            }
        }
        
        
        return self
        /*
            .onKeyPress(.leftArrow, action: handler(for: .h))
            .onKeyPress(.downArrow, action: handler(for: .j))
            .onKeyPress(.upArrow, action: handler(for: .k))
            .onKeyPress(.rightArrow, action: handler(for: .l))
        
            .onKeyPress(.init("h"), action: handler(for: .h))
            .onKeyPress(.init("j"), action: handler(for: .j))
            .onKeyPress(.init("k"), action: handler(for: .k))
            .onKeyPress(.init("l"), action: handler(for: .l))

            .onKeyPress(.init("r"), action: handler(for: .r))
            .onKeyPress(.init("f"), action: handler(for: .f))
            .onKeyPress(.init("t"), action: handler(for: .t))
            .onKeyPress(.init("v"), action: handler(for: .v))
            .onKeyPress(.init("u"), action: handler(for: .u))
        
            .onKeyPress(.init("ｈ"), action: handler(for: .h))
            .onKeyPress(.init("ｊ"), action: handler(for: .j))
            .onKeyPress(.init("ｋ"), action: handler(for: .k))
            .onKeyPress(.init("ｌ"), action: handler(for: .l))

            .onKeyPress(.init("ｒ"), action: handler(for: .r))
            .onKeyPress(.init("ｆ"), action: handler(for: .f))
            .onKeyPress(.init("ｔ"), action: handler(for: .t))
            .onKeyPress(.init("ｖ"), action: handler(for: .v))
            .onKeyPress(.init("う"), action: handler(for: .u))
        
            .onKeyPress(.init("ㅗ"), action: handler(for: .h))
            .onKeyPress(.init("ㅓ"), action: handler(for: .j))
            .onKeyPress(.init("ㅏ"), action: handler(for: .k))
            .onKeyPress(.init("ㅣ"), action: handler(for: .l))

            .onKeyPress(.init("ㄱ"), action: handler(for: .r))
            .onKeyPress(.init("ㄹ"), action: handler(for: .f))
            .onKeyPress(.init("ㅅ"), action: handler(for: .t))
            .onKeyPress(.init("ㅍ"), action: handler(for: .v))
            .onKeyPress(.init("ㅕ"), action: handler(for: .u))
         */
    }
}
