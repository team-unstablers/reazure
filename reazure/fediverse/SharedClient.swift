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

typealias Timeline = OrderedSet<StatusModel>
typealias NotificationTimeline = OrderedSet<Mastodon.Notification>

struct TLFocusState: Hashable {
    var id: String
    var depth: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(depth)
    }
}

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
    var focusState: [TimelineType: TLFocusState] = [:]
    
    @Published
    var postAreaFocused: Bool = false
    
    @Published
    var currentTab: Tab = .home
    
    var replyTo = CurrentValueSubject<StatusAdaptor?, Never>(nil)
    
    func fetchStatuses(for type: TimelineType) async {
        assert(type != .notifications)
        
        do {
            // TODO
            guard let statuses = try await client?.homeTimeline() else {
                return
            }
            
            DispatchQueue.main.async {
                for status in statuses.reversed() {
                    let adaptor = MastodonStatusAdaptor(from: status)
                    let model = StatusModel(adaptor: adaptor)
                    self.timeline[type]?.insert(model, at: 0)
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
    
    func focusedStatus(for type: TimelineType) -> StatusAdaptor? {
        guard let focusState = focusState[type],
              let model = timeline[type]?.get(id: focusState.id) else {
            return nil
        }
        
        if (focusState.depth == 0) {
            return model.status
        } else {
            return model.parents[focusState.depth - 1]
        }
    }
    
    func withFocusedStatus(for type: TimelineType, _ block: (StatusAdaptor?) -> StatusAdaptor?) {
        guard let focusState = focusState[type],
              let model = timeline[type]?.get(id: focusState.id) else {
            return
        }
        
        
        let focusedStatus: any StatusAdaptor = (focusState.depth == 0) ?
            model.status :
            model.parents[focusState.depth - 1]
       
        guard let modified = block(focusedStatus) else {
            return
        }
        
        DispatchQueue.main.async {
            if (focusState.depth == 0) {
                model.status = modified
            } else {
                model.parents[focusState.depth - 1] = modified
            }
        }
    }
}

extension SharedClient: StreamingClientDelegate {
    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient) {
        switch event.event {
        case "update":
            do {
                guard let payload = event.payload else {
                    print("XXX: Invalid payload")
                    return
                }
                
                let status = try JSON.parse(payload, to: Mastodon.Status.self)
                // home timeline
                
                DispatchQueue.main.async {
                    let adaptor = MastodonStatusAdaptor(from: status)
                    let model = StatusModel(adaptor: adaptor)
                    self.timeline[.home]?.insert(model, at: 0)
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
    func get(id: String) -> StatusModel? {
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
        guard let timeline = self.timeline[.home] else {
            return
        }
        
        guard let focusState = self.focusState[.home],
              let index = timeline.firstIndex(where: { $0.id == focusState.id })
        else {
            guard let index = timeline.first?.id else {
                return
            }
            self.focusState[.home] = TLFocusState(id: index, depth: 0)
            return
        }
        
        
        let model = timeline[index]
        
        if (focusState.depth < model.expandedDepth) {
            self.focusState[.home] = TLFocusState(id: model.id, depth: focusState.depth + 1)
        } else {
            let nextIndex = max(0, min(index + 1, timeline.count - 1))
            let nextId = timeline[nextIndex].id
            
            self.focusState[.home] = TLFocusState(id: nextId, depth: 0)
        }
    }
    
    func up() {
        guard let timeline = self.timeline[.home] else {
            return
        }
        
        guard let focusState = self.focusState[.home],
              let index = timeline.firstIndex(where: { $0.id == focusState.id })
        else {
            guard let index = timeline.first?.id else {
                return
            }
            self.focusState[.home] = TLFocusState(id: index, depth: 0)
            return
        }
        
        let model = timeline[index]
        
        if (focusState.depth > 0) {
            self.focusState[.home] = TLFocusState(id: model.id, depth: focusState.depth - 1)
        } else {
            let prevIndex = max(0, min(index - 1, timeline.count - 1))
            let prevModel = timeline[prevIndex]
            
            self.focusState[.home] = TLFocusState(id: prevModel.id, depth: prevModel.expandedDepth)
        }
    }
    
    func r() {
        self.replyTo.send(self.focusedStatus(for: .home))
    }
    
    func f() {
        self.withFocusedStatus(for: .home) { status in
            guard let status = status else {
                return nil
            }
            
            // FIXME: this is a workaround for the API not updating the status object
            // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
            if (!status.favourited) {
                Task {
                    try? await self.client?.favourite(statusId: status.id)
                }
                
                return status.mask(favourited: true)
            } else {
                Task {
                    try? await self.client?.unfavourite(statusId: status.id)
                }
                
                return status.mask(favourited: false)
            }
        }
    }
    
    func t() {
        self.withFocusedStatus(for: .home) { status in
            guard let status = status else {
                return nil
            }
            
            // FIXME: this is a workaround for the API not updating the status object
            // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
            if (!status.reblogged) {
                Task {
                    try? await self.client?.reblog(statusId: status.id)
                }
                
                return status.mask(reblogged: true)
            } else {
                Task {
                    try? await self.client?.unreblog(statusId: status.id)
                }
                
                return status.mask(reblogged: false)
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
