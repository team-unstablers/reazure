//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct NotificationItem: View, Equatable {
    var notification: Notification
    
    var body: some View {
        if let status = notification.status {
            if notification.type == "reblog" {
                PostItem(status: status, type: .reblog, relatedUser: notification.account!)
            } else if notification.type == "favourite" {
                PostItem(status: status, type: .favourite, relatedUser: notification.account!)
            } else {
                PostItem(status: status)
            }
        }
    }
    
    static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
        return lhs.notification.id == rhs.notification.id
    }
}
