//
//  Status.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI

class NotificationModel: ObservableObject {
    @Published
    var notification: NotificationAdaptor
    
    @Published
    var statusModel: StatusModel?
    
    init(adaptor notification: NotificationAdaptor) {
        self.notification = notification
        
        if let status = notification.status {
            self.statusModel = StatusModel(adaptor: status)
        }
    }
}

extension NotificationModel: Hashable, Equatable, Identifiable {
    static func == (lhs: NotificationModel, rhs: NotificationModel) -> Bool {
        return lhs.notification.id == rhs.notification.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(notification.id)
    }
    
    var id: String {
        return notification.id
    }
}
