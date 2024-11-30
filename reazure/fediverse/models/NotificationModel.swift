//
//  NotificationModel.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

class NotificationModel: StatusModel {
    
    @Published
    var notification: NotificationAdaptor
    
    
    init?(adaptor notification: NotificationAdaptor, performer: Performer? = nil) {
        guard let status = notification.status else {
            // FIXME: support other types of notification
            return nil
        }
        
        self.notification = notification
        
        super.init(adaptor: status, performer: performer)
    }
}
