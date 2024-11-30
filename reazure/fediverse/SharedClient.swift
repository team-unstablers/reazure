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

class SharedClient: ObservableObject {
    static let shared = SharedClient()
    
    @Published
    var account: Account? {
        didSet {
            didAccountChanged(account: account)
        }
    }
    
    var client: MastodonClient?
    var streamingClient: StreamingClient?

    @Published
    var configuration: FediverseServerConfiguration?
    
    @Published
    var streamingState: StreamingState = .disconnected
    
    @Published
    var timeline: [TimelineType: TimelineModel] = [:]
    
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
    
    var currentTimeline: TimelineModel? {
        switch currentTab {
        case .home:
            return timeline[.home]
        case .notification:
            return timeline[.notifications]
        default:
            return nil
        }
    }
    
    var replyTo = CurrentValueSubject<StatusAdaptor?, Never>(nil)
    
    private init() {
        self.constructTimelineModel()
    }
    
    private func constructTimelineModel() {
        let homeTimeline = TimelineModel(with: self) { [weak self] (args) in
            guard let statuses = try await self?.client?.homeTimeline() else {
                return []
            }
            
            return statuses.map { StatusModel(adaptor: MastodonStatusAdaptor(from: $0), performer: self) }
        }
        
        let notificationsTimeline = TimelineModel(with: self) { [weak self] (args) in
            guard let notifications = try await self?.client?.notifications() else {
                return []
            }
            
            return notifications.compactMap { NotificationModel(adaptor: MastodonNotificationAdaptor(from: $0), performer: self) }
        }
        
        timeline = [
            .home: homeTimeline,
            .notifications: notificationsTimeline
        ]
        
    }
    
    private func didAccountChanged(account: Account?) {
        self.constructTimelineModel()
        
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
                    let model = StatusModel(adaptor: adaptor, performer: self)
                    self.timeline[.home]?.prepend(model)
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
                    guard let model = NotificationModel(adaptor: adaptor, performer: self) else {
                        return
                    }
                    
                    self.timeline[.notifications]?.prepend(model)
                    
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
                    self.timeline[.home]?.update()
                }
                
                guard let configuration = self.configuration else {
                    return
                }
                
                client.start(configuration)
            }
        }
    }
}

extension SharedClient {
    func handleShortcut(key: ShortcutKey) {
        switch key {
        case .u:
            postAreaFocused.toggle()
        default:
            self.currentTimeline?.handleShortcut(key)
        }
    }
}

