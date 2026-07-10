//
//  TimelineModel.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

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
                    
                    self.statuses.sort { $0.id > $1.id }
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
