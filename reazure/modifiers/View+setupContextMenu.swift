//
//  PostItem+setupContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import Foundation
import SwiftUI


extension View {
    func setupContextMenu(_ status: StatusAdaptor) -> some View {
        self.modifier(SetupContextMenuModifier(status: status))
    }
}


struct SetupContextMenuModifier: ViewModifier {
    @Environment(\.openURL)
    var openURL
    
    let status: StatusAdaptor
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .contextMenu {
                NativePostContextMenuInner(status: status)
            }
    }
}
