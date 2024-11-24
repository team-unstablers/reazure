//
//  TimelineView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct NotificationTimelineView: View {
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @FocusState
    var focusState: TLFocusState?
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sharedClient.notifications) { model in
                    if let statusModel = model.statusModel {
                        NotificationGroup(model: model, statusModel: statusModel, focusState: $focusState, scrollViewProxy: proxy)
                    } else {
                        EmptyView()
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .padding(0)
            .environment(\.defaultMinListRowHeight, 0)
            .onChange(of: sharedClient.focusState[.notifications]) { oldValue, value in
                if oldValue == value {
                    return
                }
                
                // proxy.scrollTo가 먼저 실행되어야 함: 왜냐하면 focusedId가 현재 표시 바깥에 있으면 포커스 안됨 / 숏컷 핸들러 안 먹게 됨
                guard let focusState = sharedClient.focusState[.notifications] else {
                    return
                }
                proxy.scrollTo(focusState)
                
                DispatchQueue.main.async {
                    self.focusState = focusState
                }
                
                // withAnimation {
                // }
            }
        }
        .onAppear {
            Task {
                await sharedClient.fetchNotification()
            }
        }
    }
}

