//
//  AccountManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation

import Collections
import Combine

enum TimelineType {
    case home
    case notifications
    case local
    case federated
}

typealias Timeline = OrderedSet<Status>
typealias NotificationTimeline = OrderedSet<Notification>

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
    
    @Published
    var notifications: NotificationTimeline = []
    
    @Published
    var focusState: [TimelineType: String] = [:]
    
    @Published
    var postAreaFocused: Bool = false
    
    var replyTo = CurrentValueSubject<Status?, Never>(nil)
    
    func fetchStatuses(for type: TimelineType) async {
        assert(type != .notifications)
        
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
    
    func fetchNotification() async {
        do {
            guard let notifications = try await client?.notifications() else {
                return
            }
            
            DispatchQueue.main.async {
                for notification in notifications.reversed() {
                    self.notifications.insert(notification, at: 0)
                }
            }
        } catch {
            // FIXME
            print(error)
        }
    }
    
    func focusedStatus(for type: TimelineType) -> Status? {
        guard let focusedId = focusState[type],
              let status = timeline[type]?.get(id: focusedId) else {
            return nil
        }
        
        return status
    }
    
    func withFocusedStatus(for type: TimelineType, _ block: (Status?) -> Status?) {
        let status = focusedStatus(for: type)
        
        guard let modified = block(status),
              let index = timeline[type]?.firstIndex(where: { $0.id == modified.id })
        else {
            return
        }
        
        timeline[type]?.update(modified, at: index)
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

extension Timeline {
    func get(id: String) -> Status? {
        return self.first { $0.id == id }
    }
}
