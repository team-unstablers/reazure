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
    var client: (any FediverseClient)? {
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
    /// delete/resolve). Owns the active `FediverseClient` reference, which is
    /// mirrored in via `client`'s `didSet` on account change.
    lazy var actionPerformer = FediverseActionPerformer(replyTo: replyTo)

    /// Presentation side effects (unread accrual + sound/haptic) for incoming
    /// streaming notifications. The unread count stays a `@Published` property
    /// here; the presenter nudges it through the injected `incrementUnread`.
    lazy var notificationPresenter = NotificationPresenter(incrementUnread: { [weak self] count in
        self?.unreadNotificationCount += count
    })

    // Streaming seams handed to each session's `StreamingCoordinator`. `.shared`
    // uses the live defaults; the injectable initializer lets tests drive the
    // whole session/streaming wiring without a network.
    private let streamingSocketProvider: WebSocketProviding
    private let streamingScheduler: ReconnectScheduling
    private let streamingConfigurationProvider: (Account) async throws -> FediverseServerConfiguration
    private let streamingPathMonitorFactory: () -> PathMonitoring

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
            backfill: { [weak self] in self?.backfillTimelines() }
        ),
        socketProvider: streamingSocketProvider,
        scheduler: streamingScheduler,
        configurationProvider: streamingConfigurationProvider,
        pathMonitorFactory: streamingPathMonitorFactory
    )

    /// Designated initializer. `.shared` uses the live streaming defaults; tests
    /// inject fakes to exercise the session/streaming wiring without a network.
    init(socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() },
         pathMonitorFactory: @escaping () -> PathMonitoring = { NWPathMonitorAdaptor() }) {
        self.streamingSocketProvider = socketProvider
        self.streamingScheduler = scheduler
        self.streamingConfigurationProvider = configurationProvider
        self.streamingPathMonitorFactory = pathMonitorFactory
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

    /// Resumes the session after the app has been away: backfills the timelines and
    /// forces the stream to reconnect immediately, bypassing the backoff. Call this
    /// on the background → foreground edge; a no-op while signed out.
    ///
    /// Both halves are needed. The socket is dead after a suspend, so the stream has
    /// to be reopened — but reopening alone recovers nothing, because streaming only
    /// delivers events from the moment it connects and never replays the gap. In a
    /// client with no offline cache, a REST backfill is the *only* thing that can
    /// close it.
    func resumeFromBackground() {
        sessionManager.reconnectStreaming()
    }

    /// REST-refreshes home + notifications to recover whatever the stream missed
    /// while it was down (app suspended, network dropped, socket dead).
    ///
    /// Driven by `StreamingCoordinator` — every path that reopens the stream runs
    /// this first, so the gap is closed no matter which one triggered it: the
    /// foreground return, a restored network path, or a backoff reconnect.
    ///
    /// Recovered notifications accrue unread exactly like streamed ones, but the
    /// alert fires at most once for the whole batch (see
    /// `NotificationPresenter.presentBackfill`). Timelines dedupe on insert, so a
    /// redundant call is cheap and reports zero new entries.
    func backfillTimelines() {
        timeline[.home]?.update()

        guard let notifications = timeline[.notifications] else {
            return
        }

        // An empty notifications timeline means the user has never opened the tab
        // (its `onAppear` does the first fetch), so this refresh is its *first* fill,
        // not a recovery: what it returns is the account's existing notification
        // history, which was never "missed" and must not land as unread. Only a
        // timeline that already had entries can meaningfully have fallen behind.
        let isFirstFill = notifications.statuses.isEmpty

        notifications.update { [weak self] recovered in
            guard let self, !isFirstFill else {
                return
            }

            self.notificationPresenter.presentBackfill(
                count: recovered,
                isNotificationTabActive: self.currentTab == .notification
            )
        }
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

