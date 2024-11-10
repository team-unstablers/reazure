//
//  AccountManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation
import Collections

enum TimelineType {
    case home
    case local
    case federated
}

typealias Timeline = OrderedSet<Status>

class SharedClient: ObservableObject {
    @Published
    var account: Account? {
        didSet {
            if let account = account {
                timeline = [
                    .home: Timeline(),
                    .local: Timeline(),
                    .federated: Timeline()
                ]
                
                client = MastodonClient(using: account)
                streamingClient = StreamingClient(using: account)
                streamingState = .disconnected
                
                streamingClient?.delegate = self
                
                streamingClient?.start()
            } else {
                client = nil
            }
        }
    }
    
    
    var client: MastodonClient?
    var streamingClient: StreamingClient?
    
    @Published
    var streamingState: StreamingState = .disconnected

    @Published
    var timeline: [TimelineType: Timeline] = [
        .home: Timeline(),
        .local: Timeline(),
        .federated: Timeline()
    ]
    
    
    func fetchStatuses(for type: TimelineType) async {
        do {
            // TODO
            guard let statuses = try await client?.homeTimeline() else {
                return
            }
            
            DispatchQueue.main.async {
                for status in statuses.reversed() {
                    self.timeline[type]?.insert(status, at: 0)
                }
            }
        } catch {
            // FIXME
            print(error)
        }
    }
}

extension SharedClient: StreamingClientDelegate {
    func didReceive(event: StreamingEvent, client: StreamingClient) {
        switch event.event {
        case "update":
            do {
                guard let payload = event.payload else {
                    print("XXX: Invalid payload")
                    return
                }
                
                let status = try JSON.parse(payload, to: Status.self)
                // home timeline
                
                DispatchQueue.main.async {
                    self.timeline[.home]?.insert(status, at: 0)
                }
                
                print("Done!")
            } catch {
                print("SharedClient:didReceive: \(error)")
            }
        default:
            break
        }
    }
    
    func didStateChange(state: StreamingState, client: StreamingClient) {
        print("streaming state changed: \(state)")
        self.streamingState = state
        
        
        if state == .disconnected {
            client.stop()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                Task {
                    await self.fetchStatuses(for: .home)
                }
                
                client.start()
                
            }
        }
    }
}
