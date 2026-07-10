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
    
    /// The active account, or `nil` while signed out. Set through `use(account:)`
    /// / `signOut()` rather than assigned directly, so the session lifecycle stays
    /// in one place.
    @Published
    var account: Account?

    /// The active session's REST client, mirrored from `AccountSession` on
    /// `use(account:)`. Its `didSet` keeps the action performer pointed at the
    /// live client.
    var client: MastodonClient? {
        didSet {
            actionPerformer.client = client
        }
    }

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

    // Streaming seams handed to each session's `StreamingCoordinator`. `.shared`
    // uses the live defaults; the injectable initializer lets tests drive the
    // whole session/streaming wiring without a network.
    private let streamingSocketProvider: WebSocketProviding
    private let streamingScheduler: ReconnectScheduling
    private let streamingConfigurationProvider: (Account) async throws -> FediverseServerConfiguration

    /// Builds and owns the live account session (client, timelines, streaming
    /// coordinator, event ingestor), centralizing the per-account creation and
    /// teardown order. Driven by `use(account:)` / `signOut()`; the session
    /// mirrors streaming state / configuration / decoded events back onto this
    /// facade through the injected environment closures.
    lazy var sessionManager = SessionManager(
        environment: SessionManager.Environment(
            performer: actionPerformer,
            presenter: notificationPresenter,
            focusPostArea: { [weak self] in self?.postAreaFocused.toggle() },
            stateDidChange: { [weak self] state in self?.streamingState = state },
            configurationDidLoad: { [weak self] configuration in self?.configuration = configuration },
            isNotificationTabActive: { [weak self] in self?.currentTab == .notification },
            backfillHome: { [weak self] in self?.timeline[.home]?.update() }
        ),
        socketProvider: streamingSocketProvider,
        scheduler: streamingScheduler,
        configurationProvider: streamingConfigurationProvider
    )

    /// Designated initializer. `.shared` uses the live streaming defaults; tests
    /// inject fakes to exercise the session/streaming wiring without a network.
    init(socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() }) {
        self.streamingSocketProvider = socketProvider
        self.streamingScheduler = scheduler
        self.streamingConfigurationProvider = configurationProvider
        self.timeline = makeIdleTimelines()
    }

    /// Switches the app to `account`: tears down any previous session, builds a
    /// new one (client, timelines, streaming), and mirrors it onto the facade's
    /// reactive surface. Views call this instead of assigning `account` directly.
    func use(account: Account) {
        streamingState = .disconnected

        let session = sessionManager.use(account: account)

        self.account = account
        self.client = session.client
        self.timeline = session.timelines
    }

    /// Tears down the current session and returns the facade to its signed-out
    /// state. The timeline map keeps `.home`/`.notifications` seeded (empty) so
    /// the views that force-unwrap those keys stay valid.
    func signOut() {
        sessionManager.signOut()

        self.client = nil
        self.account = nil
        self.streamingState = .disconnected
        self.timeline = makeIdleTimelines()
    }

    /// Empty home / notifications timelines for the signed-out state (no fetch
    /// client), keeping both keys present for the facade's force-unwraps.
    private func makeIdleTimelines() -> [TimelineType: TimelineModel] {
        let focus: () -> Void = { [weak self] in self?.postAreaFocused.toggle() }
        return [
            .home: TimelineModel(focusPostArea: focus),
            .notifications: TimelineModel(focusPostArea: focus)
        ]
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

