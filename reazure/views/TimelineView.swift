//
//  TimelineView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct NoButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
    }
}


struct TimelineView: View {
    var type: TimelineType
    
    @ObservedObject
    var timeline: TimelineModel
    
    /*
    @FocusState
    var focusedId: String?
     */
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(timeline.statuses) { model in
                    PostGroup(model: model, scrollViewProxy: proxy) { focusState in
                        timeline.focusState = focusState
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .padding(0)
            .environment(\.defaultMinListRowHeight, 0)
            .environment(\.tlFocusState, timeline.focusState)
            .onChange(of: timeline.focusState) { (oldValue, newValue) in
                if (oldValue == newValue) {
                    return
                }
                
                // proxy.scrollTo가 먼저 실행되어야 함: 왜냐하면 focusedId가 현재 표시 바깥에 있으면 포커스 안됨 / 숏컷 핸들러 안 먹게 됨
                guard let focusState = newValue else {
                    return
                }
                proxy.scrollTo(focusState)
            }
        }
        .onAppear {
            timeline.update()
        }
    }
}

