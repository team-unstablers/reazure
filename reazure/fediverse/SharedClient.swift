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
    
    var client: MastodonClient? {
        didSet {
            actionPerformer.client = client
        }
    }

    /// Owns the streaming lifecycle (client, configuration fetch, reconnect loop)
    /// for the active account. Rebuilt per account; `nil` while signed out. The
    /// facade keeps the `@Published streamingState`/`configuration` surface and
    /// the coordinator mirrors into it through callbacks.
    private var streamingCoordinator: StreamingCoordinator?

    /// Decodes streaming events into timeline mutations behind a server-agnostic
    /// decode seam. Rebuilt per account (its decoder is server-specific); the
    /// coordinator forwards decoded events here.
    private var eventIngestor: EventIngestor?

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
    
    let replyTo = CurrentValueSubject<StatusAdaptor?, Never>(nil)

    /// Concrete executor for status-model write actions (reblog/favourite/reply/
    /// delete/resolve). Owns the active `MastodonClient` reference, which is
    /// mirrored in via `client`'s `didSet` on account change.
    lazy var actionPerformer = MastodonActionPerformer(replyTo: replyTo)

    /// Presentation side effects (unread accrual + sound/haptic) for incoming
    /// streaming notifications. The unread count stays a `@Published` property
    /// here; the presenter nudges it through the injected `incrementUnread`.
    lazy var notificationPresenter = NotificationPresenter(incrementUnread: { [weak self] in
        self?.unreadNotificationCount += 1
    })

    private init() {
        self.constructTimelineModel()
    }
    
    private func constructTimelineModel() {
        let homeTimeline = TimelineModel(focusPostArea: { [weak self] in self?.postAreaFocused.toggle() }) { [weak self] (args) in
            guard let statuses = try await self?.client?.homeTimeline() else {
                return []
            }

            return statuses.map { StatusModel(adaptor: MastodonStatusAdaptor(from: $0), performer: self?.actionPerformer) }
        }

        let notificationsTimeline = TimelineModel(focusPostArea: { [weak self] in self?.postAreaFocused.toggle() }) { [weak self] (args) in
            guard let notifications = try await self?.client?.notifications() else {
                return []
            }
            
            return notifications.compactMap { NotificationModel(adaptor: MastodonNotificationAdaptor(from: $0), performer: self?.actionPerformer) }
        }
        
        timeline = [
            .home: homeTimeline,
            .notifications: notificationsTimeline
        ]
        
    }
    
    private func didAccountChanged(account: Account?) {
        self.constructTimelineModel()

        // Tear down the previous session's streaming first: `stop()` cancels any
        // pending reconnect so a superseded coordinator can never resurrect a
        // socket for the old account.
        streamingCoordinator?.stop()
        streamingCoordinator = nil
        eventIngestor = nil

        client = nil
        streamingState = .disconnected

        if let account = account {
            client = MastodonClient(using: account)

            let ingestor = EventIngestor(
                decoder: account.server.streamingEventDecoder(),
                performer: actionPerformer,
                presenter: notificationPresenter,
                homeTimeline: { [weak self] in self?.timeline[.home] },
                notificationTimeline: { [weak self] in self?.timeline[.notifications] },
                isNotificationTabActive: { [weak self] in self?.currentTab == .notification }
            )
            eventIngestor = ingestor

            let coordinator = StreamingCoordinator(
                account: account,
                callbacks: StreamingCoordinator.Callbacks(
                    stateDidChange: { [weak self] state in
                        self?.streamingState = state
                    },
                    configurationDidLoad: { [weak self] configuration in
                        self?.configuration = configuration
                    },
                    didReceiveEvent: { [weak self] event in
                        self?.eventIngestor?.ingest(event)
                    },
                    backfillHome: { [weak self] in
                        self?.timeline[.home]?.update()
                    }
                )
            )
            streamingCoordinator = coordinator
            coordinator.start()
        }
    }
}

extension SharedClient {
    /// Submits a new post through the action performer so composer views never
    /// reach into `client` (or the performer) directly.
    func post(_ request: PostRequest) async throws {
        try await actionPerformer.post(request)
    }
}

extension SharedClient: ShortcutRouting {
    func handleShortcut(key: ShortcutKey) {
        switch key {
        case .u:
            postAreaFocused.toggle()
        default:
            self.currentTimeline?.handleShortcut(key)
        }
    }
}

