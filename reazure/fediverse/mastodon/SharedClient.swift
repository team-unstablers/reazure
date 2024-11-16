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


enum Tab {
    case home
    case notification
    case profile
    case settings
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
    
    @Published
    var currentTab: Tab = .home
    
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
        
        DispatchQueue.main.async {
            self.timeline[type]?.update(modified, at: index)
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

extension Timeline {
    func get(id: String) -> Status? {
        return self.first { $0.id == id }
    }
}

enum ShortcutKey {
    case h
    case j
    case k
    case l
    
    case r
    case f
    case t
    case v
    case u
    
    case one
    case two
    case three
    case four
}


fileprivate extension SharedClient {
    func down() {
        guard let focusedId = self.focusState[.home],
              let index = self.timeline[.home]?.firstIndex(where: { $0.id == focusedId })
        else {
            self.focusState[.home] = self.timeline[.home]?.first?.id
            return
        }
        
        let timeline = self.timeline[.home]!
        
        let nextIndex = max(0, min(index + 1, timeline.count - 1))
        let nextId = timeline[nextIndex].id
        
        self.focusState[.home] = nextId
    }
    
    func up() {
        guard let focusedId = self.focusState[.home],
              let index = self.timeline[.home]?.firstIndex(where: { $0.id == focusedId })
        else {
            self.focusState[.home] = self.timeline[.home]?.first?.id
            return
        }
        
        let timeline = self.timeline[.home]!
        
        let prevIndex = max(0, min(index - 1, timeline.count - 1))
        let prevId = timeline[prevIndex].id
        
        self.focusState[.home] = prevId
    }
    
    func r() {
        self.replyTo.send(self.focusedStatus(for: .home))
    }
    
    func f() {
        self.withFocusedStatus(for: .home) { status in
            guard let status = status else {
                return nil
            }
            
            var modified = status
            
            // FIXME: this is a workaround for the API not updating the status object
            // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
            if (!status.favourited) {
                Task {
                    try? await self.client?.favourite(statusId: status.id)
                }
                modified.favourited = true
                
                return modified
            } else {
                Task {
                    try? await self.client?.unfavourite(statusId: status.id)
                }
                modified.favourited = false
                
                return modified
            }
        }
    }
    
    func t() {
        self.withFocusedStatus(for: .home) { status in
            guard let status = status else {
                return nil
            }
            
            var modified = status
            
            // FIXME: this is a workaround for the API not updating the status object
            // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
            if (!status.reblogged) {
                Task {
                    try? await self.client?.reblog(statusId: status.id)
                }
                modified.reblogged = true
                
                return modified
            } else {
                Task {
                    try? await self.client?.unreblog(statusId: status.id)
                }
                modified.reblogged = false
                
                return modified
            }
        }
    }
    
    func u() {
        self.postAreaFocused.toggle()
    }
    
    func one() {
        self.currentTab = .home
    }
    
    func two() {
        self.currentTab = .notification
    }
    
    func three() {
        self.currentTab = .profile
    }
    
    func four() {
        self.currentTab = .settings
    }
}


extension SharedClient {
    func handleShortcut(key: ShortcutKey) {
        DispatchQueue.main.async {
            switch key {
            case .h:
                break
            case .j:
                self.down()
            case .k:
                self.up()
            case .l:
                break
            case .r:
                self.r()
            case .f:
                self.f()
            case .t:
                self.t()
            case .v:
                break
            case .u:
                self.u()
            case .one:
                self.one()
            case .two:
                self.two()
            case .three:
                self.three()
            case .four:
                self.four()
            default:
                break
            }
        }
    }
}
