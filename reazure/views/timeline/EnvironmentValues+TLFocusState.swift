//
//  EnvironmentValues+focusState.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import SwiftUI

private struct TLFocusStateKey: EnvironmentKey {
    static let defaultValue: TimelineModel.FocusState? = nil
}

extension EnvironmentValues {
    var tlFocusState: TimelineModel.FocusState? {
        get { self[TLFocusStateKey.self] }
        set { self[TLFocusStateKey.self] = newValue }
    }
}
