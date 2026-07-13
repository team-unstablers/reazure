//
//  TimelineModel.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Combine
import Foundation

import Collections


struct TimelineFetchArgs {
    var sinceId: String?
    var untilId: String?
    var limit: Int?
}


class TimelineModel: ObservableObject {
    typealias FetchFunction = (TimelineFetchArgs) async throws -> [StatusModel]
    
    struct FocusState: Hashable {
        var id: String
        var depth: Int
    }
    
    /// Narrow seam for the `.u` shortcut to focus the post composer. Injected as
    /// a closure so `TimelineModel` no longer holds a strong back-reference to
    /// `SharedClient` (the former hub cycle, kept alive only by the immortal
    /// singleton). Production wires this to `SharedClient.postAreaFocused.toggle`.
    let focusPostArea: () -> Void

    /// Fired by the `.v` shortcut (hardware keyboard / ExtKeypad) with the
    /// focus state whose row should present its context menu. Presentation is
    /// delegated to the matching row's `ProgrammaticContextMenuHost`, since a
    /// context menu can only be presented from a view.
    let contextMenuRequest = PassthroughSubject<FocusState, Never>()

    @Published
    var statuses: OrderedSet<StatusModel> = []

    @Published
    var focusState: FocusState? = nil

    var fetchFunction: FetchFunction?

    init(focusPostArea: @escaping () -> Void = {}, fetchFunction: FetchFunction? = nil) {
        self.focusPostArea = focusPostArea
        self.fetchFunction = fetchFunction
    }
    
    func clear() {
        focusState = nil
        statuses = []
    }
    
    func update() {
        guard let fetchFunction = fetchFunction else {
            return
        }
        
        var args = TimelineFetchArgs()

        Task {
            do {
                let statuses = try await fetchFunction(args)
                
                DispatchQueue.main.async {
                    for status in statuses {
                        self.statuses.insert(status, at: 0)
                    }

                    self.statuses.sort { $0.sortKey > $1.sortKey }
                }
            } catch {
                // FIXME
                print(error)
            }
        }
    }
    
    func prepend(_ status: StatusModel) {
        statuses.insert(status, at: 0)
    }
}
