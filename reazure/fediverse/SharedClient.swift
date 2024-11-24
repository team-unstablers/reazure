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
typealias NotificationTimeline = OrderedSet<NotificationModel>

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
            timeline = [
                .home: Timeline(),
                .local: Timeline(),
                .federated: Timeline()
            ]
            
            streamingClient?.delegate = nil
            streamingClient?.stop()
            
            client = nil
            streamingClient = nil
            
            streamingState = .disconnected
            
            if let account = account {
                client = MastodonClient(using: account)
                streamingClient = StreamingClient(using: account)
                streamingState = .disconnected
                
                streamingClient?.delegate = self

                Task {
                    // FIXME: handle errors
                    guard let configuration = try? await account.server.configuration() else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.configuration = configuration
                    }
                    streamingClient?.start(configuration)
                }
            } else {
                client = nil
            }
        }
    }
    
    var client: MastodonClient?
    var streamingClient: StreamingClient?

    @Published
    var configuration: FediverseServerConfiguration?
    
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
    var currentTab: Tab = .home {
        didSet {
            if (currentTab == .notification) {
                unreadNotificationCount = 0
            }
        }
    }
    
    // FIXME
    @Published
    var unreadNotificationCount: Int = 0
    
    var currentTimeline: TimelineType? {
        switch currentTab {
        case .home:
            return .home
        case .notification:
            return .notifications
        default:
            return nil
        }
    }
    
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
                    let adaptor = MastodonNotificationAdaptor(from: notification)
                    let model = NotificationModel(adaptor: adaptor)
                    
                    self.notifications.insert(model, at: 0)
                }
            }
        } catch {
            // FIXME
            print(error)
        }
    }
    
    func focusedModel(for type: TimelineType) -> StatusModel? {
        guard let focusState = focusState[type] else {
            return nil
        }
        
        if type == .notifications {
            return notifications.get(id: focusState.id)?.statusModel
        }
        
        return timeline[type]?.get(id: focusState.id)
    }
    
    func focusedStatus(for type: TimelineType) -> StatusAdaptor? {
        guard let focusState = focusState[type],
              let model = self.focusedModel(for: type) else {
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
              let model = self.focusedModel(for: type) else {
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
            } catch {
                print("SharedClient:didReceive: \(error)")
            }
            break
        case "notification":
            do {
                guard let payload = event.payload else {
                    print("XXX: Invalid payload")
                    return
                }
                
                let notification = try JSON.parse(payload, to: Mastodon.Notification.self)
                
                DispatchQueue.main.async {
                    let adaptor = MastodonNotificationAdaptor(from: notification)
                    let model = NotificationModel(adaptor: adaptor)
                    
                    self.notifications.insert(model, at: 0)
                    
                    if (self.currentTab != .notification) {
                        self.unreadNotificationCount += 1
                    }
                    
                    let preferencesManager = PreferencesManager.shared
                    let notifySound = preferencesManager.notificationSound
                    let shouldPlaySound = preferencesManager.playSoundOnNotification
                    let shouldVibrate = (
                        preferencesManager.vibrateOnNotification
                    )
                    
                    if (shouldPlaySound) {
                        notifySound.play()
                    } else if (shouldVibrate) {
                        HapticManager.shared.vibrate()
                    }
                }
            } catch {
                print("SharedClient:didReceive: \(error)")
            }
            break
        default:
            break
        }
    }
    
    func didStateChange(state: StreamingState, client: StreamingClient) {
        print("streaming state changed: \(state)")
        DispatchQueue.main.async {
            self.streamingState = state
        }
        
        
        if state == .disconnected {
            client.stop()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                Task {
                    await self.fetchStatuses(for: .home)
                }
                
                guard let configuration = self.configuration else {
                    return
                }
                
                client.start(configuration)
            }
        }
    }
}

extension Timeline {
    func get(id: String) -> StatusModel? {
        return self.first { $0.id == id }
    }
    
    func nextFocus(_ focusState: TLFocusState?) -> TLFocusState? {
        guard let focusState = focusState,
              let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = self.first?.id else {
                return nil
            }
            
            return TLFocusState(id: index, depth: 0)
        }
        
        let model = self[index]
        
        if (focusState.depth < model.expandedDepth) {
            return TLFocusState(id: model.id, depth: focusState.depth + 1)
        } else {
            let nextIndex = Swift.max(0, Swift.min(index + 1, self.count - 1))
            let nextId = self[nextIndex].id
            
            return TLFocusState(id: nextId, depth: 0)
        }
    }
    
    func previousFocus(_ focusState: TLFocusState?) -> TLFocusState? {
        guard let focusState = focusState,
              let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = self.first?.id else {
                return nil
            }
            
            return TLFocusState(id: index, depth: 0)
        }
        
        if (index == 0 && focusState.depth == 0) {
            // self.postAreaFocused = true
            return nil
        }
        
        let model = self[index]
        
        if (focusState.depth > 0) {
            return TLFocusState(id: model.id, depth: focusState.depth - 1)
        } else {
            let prevIndex = Swift.max(0, Swift.min(index - 1, self.count - 1))
            let prevModel = self[prevIndex]
            
            return TLFocusState(id: prevModel.id, depth: prevModel.expandedDepth)
        }
    }
    
    func expand(_ focusState: TLFocusState, client: MastodonClient) {
        guard let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            return
        }
        
        let model = self[index]
        
        let focusedStatus: any StatusAdaptor = (focusState.depth == 0) ?
            model.status :
            model.parents[focusState.depth - 1]
        
        if focusedStatus.replyToId == nil {
            return
        }

        model.expandedDepth = focusState.depth + 1
        
        
        if (model.parents.count < focusState.depth + 1) {
            model.resolveParent(of: focusedStatus, using: client)
        }
    }
    
    func collapse(_ focusState: TLFocusState) -> TLFocusState? {
        guard let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            return nil
        }
        
        let model = self[index]
        
        model.expandedDepth = Swift.max(0, focusState.depth - 1)
        
        return TLFocusState(id: model.id, depth: model.expandedDepth)
    }
}

extension NotificationTimeline {
    func get(id: String) -> NotificationModel? {
        return self.first { $0.id == id }
    }
        
    func nextFocus(_ focusState: TLFocusState?) -> TLFocusState? {
        guard let focusState = focusState,
              let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = self.first?.id else {
                return nil
            }
            
            return TLFocusState(id: index, depth: 0)
        }
        
        let model = self[index]
        
        
        
        if (focusState.depth < model.statusModel?.expandedDepth ?? 0) {
            return TLFocusState(id: model.id, depth: focusState.depth + 1)
        } else {
            let nextIndex = Swift.max(0, Swift.min(index + 1, self.count - 1))
            let nextId = self[nextIndex].id
            
            return TLFocusState(id: nextId, depth: 0)
        }
    }
    
    func previousFocus(_ focusState: TLFocusState?) -> TLFocusState? {
        guard let focusState = focusState,
              let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = self.first?.id else {
                return nil
            }
            
            return TLFocusState(id: index, depth: 0)
        }
        
        if (index == 0 && focusState.depth == 0) {
            // self.postAreaFocused = true
            return nil
        }
        
        let model = self[index]
        
        if (focusState.depth > 0) {
            return TLFocusState(id: model.id, depth: focusState.depth - 1)
        } else {
            let prevIndex = Swift.max(0, Swift.min(index - 1, self.count - 1))
            let prevModel = self[prevIndex]
            
            return TLFocusState(id: prevModel.id, depth: prevModel.statusModel?.expandedDepth ?? 0)
        }
    }
    
    func expand(_ focusState: TLFocusState, client: MastodonClient) {
        guard let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            return
        }
        
        let model = self[index]
        guard let statusModel = model.statusModel else {
            return
        }
        
        let focusedStatus: any StatusAdaptor = (focusState.depth == 0) ?
            statusModel.status :
            statusModel.parents[focusState.depth - 1]
        
        if focusedStatus.replyToId == nil {
            return
        }

        statusModel.expandedDepth = focusState.depth + 1
        
        
        if (statusModel.parents.count < focusState.depth + 1) {
            statusModel.resolveParent(of: focusedStatus, using: client)
        }
    }
    
    func collapse(_ focusState: TLFocusState) -> TLFocusState? {
        guard let index = self.firstIndex(where: { $0.id == focusState.id }) else {
            return nil
        }
        
        let model = self[index]
        
        guard let statusModel = model.statusModel else {
            return nil
        }
        
        statusModel.expandedDepth = Swift.max(0, focusState.depth - 1)
        
        return TLFocusState(id: model.id, depth: statusModel.expandedDepth)
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
        guard let type = self.currentTimeline else {
            return
        }
        
        let focusState = self.focusState[type]
        
        if type == .notifications {
             guard let newState = self.notifications.nextFocus(focusState) else {
                return
            }
            self.focusState[type] = newState
           
        } else {
            guard let newState = self.timeline[type]?.nextFocus(focusState) else {
                return
            }
            self.focusState[type] = newState
        }
    }
    
    func left() {
        guard let type = self.currentTimeline,
              let focusState = self.focusState[type] else {
            return
        }
        
        if type == .notifications {
            self.focusState[type] = self.notifications.collapse(focusState)
        } else {
            self.focusState[type] = self.timeline[type]?.collapse(focusState)
        }
    }
        
    
    func right() {
        guard let client = self.client,
              let type = self.currentTimeline,
              let focusState = self.focusState[type] else {
            return
        }
        
        if type == .notifications {
            self.notifications.expand(focusState, client: client)
        } else {
            self.timeline[type]?.expand(focusState, client: client)
        }
    }
    
    func up() {
        guard let type = self.currentTimeline else {
            return
        }
        
        let focusState = self.focusState[type]
        
        if type == .notifications {
             guard let newState = self.notifications.previousFocus(focusState) else {
                return
            }
            self.focusState[type] = newState
        } else {
            guard let newState = self.timeline[type]?.previousFocus(focusState) else {
                return
            }
            self.focusState[type] = newState
        }
    }
    
    func r() {
        guard let type = self.currentTimeline else {
            return
        }

        self.replyTo.send(self.focusedStatus(for: type))
    }
    
    func f() {
        guard let type = self.currentTimeline else {
            return
        }

        self.withFocusedStatus(for: type) { status in
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
        guard let type = self.currentTimeline else {
            return
        }

        self.withFocusedStatus(for: type) { status in
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
                self.left()
            case .j:
                self.down()
            case .k:
                self.up()
            case .l:
                self.right()
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
