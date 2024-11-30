//
//  PostItem+setupContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import Foundation
import SwiftUI


extension View {
    func setupContextMenu(_ model: StatusModel, depth: Int) -> some View {
        self.modifier(SetupContextMenuModifier(model: model, depth: depth))
    }
}


struct SetupContextMenuModifier: ViewModifier {
    @Environment(\.openURL)
    var openURL
    
    let model: StatusModel
    let depth: Int
    
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .contextMenu {
                NativePostContextMenuInner(model: model, depth: depth)
            }
    }
}
