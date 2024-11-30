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
    
    var sharedClient: SharedClient
    
    @Published
    var statuses: OrderedSet<StatusModel> = []
    
    @Published
    var focusState: FocusState? = nil
    
    var fetchFunction: FetchFunction?
    
    init(with sharedClient: SharedClient, fetchFunction: FetchFunction? = nil) {
        self.sharedClient = sharedClient
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
