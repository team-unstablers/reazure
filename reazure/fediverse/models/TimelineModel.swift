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

    /// Guards against overlapping REST refreshes. A backfill can be triggered from
    /// several sources at once — a foreground return and a restored network path
    /// routinely land together — and the duplicate fetches would be pure waste,
    /// since the merge dedupes them anyway. Main-thread confined, like every other
    /// mutation here.
    private var isFetching: Bool = false

    init(focusPostArea: @escaping () -> Void = {}, fetchFunction: FetchFunction? = nil) {
        self.focusPostArea = focusPostArea
        self.fetchFunction = fetchFunction
    }

    func clear() {
        focusState = nil
        statuses = []
    }

    /// REST-fetches the timeline and merges the result into `statuses`.
    ///
    /// - Parameter completion: run on the main thread with the number of entries
    ///   that were *newly* inserted — zero when the timeline was already up to
    ///   date, when a fetch is already in flight, or when the fetch failed. Lets a
    ///   caller tell "caught up on N missed entries" apart from a no-op refresh.
    ///   Note the initial load reports its count through this too, so a caller that
    ///   only cares about backfills must make that distinction itself.
    func update(completion: ((Int) -> Void)? = nil) {
        guard let fetchFunction = fetchFunction else {
            completion?(0)
            return
        }

        guard !isFetching else {
            completion?(0)
            return
        }
        isFetching = true

        var args = TimelineFetchArgs()

        Task {
            do {
                let statuses = try await fetchFunction(args)

                DispatchQueue.main.async {
                    var inserted = 0
                    for status in statuses {
                        if self.statuses.insert(status, at: 0).inserted {
                            inserted += 1
                        }
                    }

                    self.statuses.sort { $0.sortKey > $1.sortKey }

                    self.isFetching = false
                    completion?(inserted)
                }
            } catch {
                // FIXME
                print(error)

                DispatchQueue.main.async {
                    self.isFetching = false
                    completion?(0)
                }
            }
        }
    }
    
    func prepend(_ status: StatusModel) {
        statuses.insert(status, at: 0)
    }

    /// Masks every row authored or boosted by `accountId`.
    ///
    /// The server stops *delivering* a blocked account's posts, but it cannot
    /// retract what the stream already handed us — and with no offline cache there
    /// is nothing to re-read the timeline from. So the rows on screen are masked in
    /// place rather than refetched.
    func applyBlock(accountId: String) {
        for status in statuses {
            status.applyBlock(accountId: accountId)
        }
    }
}
