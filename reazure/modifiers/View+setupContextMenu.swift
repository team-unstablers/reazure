//
//  PostItem+setupContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import Combine
import Foundation
import SwiftUI


extension View {
    func setupContextMenu(
        _ model: StatusModel,
        depth: Int,
        presentRequest: AnyPublisher<TimelineModel.FocusState, Never>
    ) -> some View {
        self.modifier(SetupContextMenuModifier(model: model, depth: depth, presentRequest: presentRequest))
    }
}


struct SetupContextMenuModifier: ViewModifier {
    let model: StatusModel
    let depth: Int
    let presentRequest: AnyPublisher<TimelineModel.FocusState, Never>


    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .contextMenu {
                NativePostContextMenuInner(model: model, depth: depth)
            }
            .overlay {
                ProgrammaticContextMenuHost(model: model, depth: depth, presentRequest: presentRequest)
            }
    }
}
