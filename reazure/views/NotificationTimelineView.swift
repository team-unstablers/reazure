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
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sharedClient.notifications) { notification in
                    Button {
                        // sharedClient.focusState[.notifications] = notification.id
                    } label: {
                        NotificationItem(notification: notification)
                            .equatable()
                            .background {
                                /*
                                if sharedClient.focusState[.notifications] == notification.id {
                                    Color(uiColor: UIColor(r8: 66, g8: 203, b8: 245, a: 0.2))
                                } else {
                                    Color.clear
                                }
                                 */
                            }
                    }
                    .zIndex(100)
                    .id(notification.id)
                    .buttonStyle(NoButtonStyle())
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .padding(0)
        }
        .onAppear {
            Task {
                await sharedClient.fetchNotification()
            }
        }
    }
}

