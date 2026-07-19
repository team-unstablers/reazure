//
//  Status.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

import SwiftUI


class StatusModel: StatusModelBase, ObservableObject {
    weak var performer: Performer?

    /// Timeline identity. A plain status row is identified by the status it
    /// wraps; `NotificationModel` overrides this with the notification id, so
    /// that several notifications about the *same* post remain distinct rows
    /// instead of collapsing into one inside the timeline's `OrderedSet`.
    let id: String

    /// Timeline ordering. Like `id`, this is the identity of the row rather than
    /// of the status: a notification row is ordered by when the notification
    /// happened, not by when the post it refers to was written.
    let sortKey: TimelineSortKey

    @Published
    var status: StatusAdaptor

    @Published
    var parents: [StatusAdaptor] = []

    @Published
    var expandedDepth: Int = 0

    @Published
    var revealedDepths: Set<Int> = []

    @Published
    var resolving: Bool = false

    convenience init(adaptor status: StatusAdaptor, performer: Performer? = nil) {
        self.init(adaptor: status,
                  id: status.id,
                  sortKey: TimelineSortKey(createdAt: status.createdAt, id: status.id),
                  performer: performer)
    }

    /// Designated initializer for subclasses whose row identity is not the
    /// wrapped status' own id.
    init(adaptor status: StatusAdaptor, id: String, sortKey: TimelineSortKey, performer: Performer?) {
        self.id = id
        self.sortKey = sortKey
        self.status = status
        self.performer = performer
    }
}

extension StatusModel: Hashable, Equatable, Identifiable {
    static func == (lhs: StatusModel, rhs: StatusModel) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
