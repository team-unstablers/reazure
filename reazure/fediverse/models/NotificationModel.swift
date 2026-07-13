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

        // The row stands for the notification, not for the post it refers to:
        // several people favouriting/boosting one post produce several rows,
        // each ordered by when that notification arrived.
        super.init(adaptor: status,
                   id: notification.id,
                   sortKey: TimelineSortKey(createdAt: notification.createdAt, id: notification.id),
                   performer: performer)
    }
}
