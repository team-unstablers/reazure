//
//  TimelineView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct TimelineView: View {
    @FocusState
    var selectedPost: String?
    
    var type: TimelineType
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    var body: some View {
        List {
            ForEach(sharedClient.timeline[type]!) { status in
                PostItem(status: status, selfId: sharedClient.account?.id ?? "")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .focusable()
                    .focused($selectedPost, equals: status.id)
                    .onTapGesture {
                        selectedPost = status.id
                    }
                    .background {
                        if selectedPost == status.id {
                            Color.red
                        } else {
                            Color.clear
                        }
                    }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .padding(0)
        .onAppear {
            Task {
                await sharedClient.fetchStatuses(for: type)
            }
        }
    }
}

