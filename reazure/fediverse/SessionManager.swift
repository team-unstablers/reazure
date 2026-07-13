//
//  SessionManager.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

/// A live account session: the per-account collaborators built and torn down as
/// a unit. Bundling them puts the creation/cleanup order in one place instead of
/// the imperative sequence the old `SharedClient.didAccountChanged` spread out,
/// and guarantees the timeline map is always seeded with `.home`/`.notifications`
/// (the facade force-unwraps those two keys).
final class AccountSession {
    let account: Account
    let client: any FediverseClient
    let timelines: [TimelineType: TimelineModel]

    private let eventIngestor: EventIngestor
    private let coordinator: StreamingCoordinator

    init(account: Account,
         client: any FediverseClient,
         timelines: [TimelineType: TimelineModel],
         eventIngestor: EventIngestor,
         coordinator: StreamingCoordinator) {
        self.account = account
        self.client = client
        self.timelines = timelines
        self.eventIngestor = eventIngestor
        self.coordinator = coordinator
    }

    /// Fetches configuration and opens the stream for this session.
    func start() {
        coordinator.start()
    }

    /// Tears down streaming, cancelling any pending reconnect. Idempotent.
    func stop() {
        coordinator.stop()
    }

    /// Forces an immediate stream reconnect, bypassing the backoff. Used when the
    /// app returns to the foreground.
    func reconnectStreaming() {
        coordinator.reconnectNow()
    }
}

/// Builds and owns the live `AccountSession`, centralizing the per-account
/// creation/teardown that used to live in `SharedClient.didAccountChanged`.
/// Switching accounts tears down the previous session (cancelling its pending
/// reconnect) before building the next; signing out just tears down.
final class SessionManager {
    /// Facade-owned collaborators and passthrough hooks a session is wired to.
    /// The streaming state / configuration / event forwarding all flow back to
    /// the facade `@Published` surface through these closures.
    struct Environment {
        let performer: StatusModelActionPerformer
        let presenter: NotificationPresenter
        let focusPostArea: () -> Void
        let stateDidChange: (StreamingState) -> Void
        let configurationDidLoad: (FediverseServerConfiguration) -> Void
        let isNotificationTabActive: () -> Bool
        /// REST-refreshes the timelines to recover what the stream missed while it
        /// was down. Run by the coordinator on every path that reopens the stream.
        let backfill: () -> Void
    }

    private let environment: Environment

    // Streaming seams passed down to each session's `StreamingCoordinator`.
    // Injectable so the whole session lifecycle can be exercised without a network.
    private let socketProvider: WebSocketProviding
    private let scheduler: ReconnectScheduling
    private let configurationProvider: (Account) async throws -> FediverseServerConfiguration
    // A factory (not a single instance) because `NWPathMonitor` is single-use: each
    // session's coordinator needs its own monitor.
    private let pathMonitorFactory: () -> PathMonitoring

    private(set) var current: AccountSession?

    init(environment: Environment,
         socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() },
         pathMonitorFactory: @escaping () -> PathMonitoring = { NWPathMonitorAdaptor() }) {
        self.environment = environment
        self.socketProvider = socketProvider
        self.scheduler = scheduler
        self.configurationProvider = configurationProvider
        self.pathMonitorFactory = pathMonitorFactory
    }

    /// Tears down the previous session and builds + starts one for `account`.
    @discardableResult
    func use(account: Account) -> AccountSession {
        signOut()

        let session = makeSession(for: account)
        current = session
        session.start()
        return session
    }

    /// Tears down the current session, if any.
    func signOut() {
        current?.stop()
        current = nil
    }

    /// Forces the current session (if any) to reconnect its stream now.
    func reconnectStreaming() {
        current?.reconnectStreaming()
    }

    private func makeSession(for account: Account) -> AccountSession {
        let client: any FediverseClient = account.server.makeClient(for: account)
        let timelines = makeTimelines(client: client)

        let ingestor = EventIngestor(
            decoder: account.server.streamingEventDecoder(),
            performer: environment.performer,
            presenter: environment.presenter,
            homeTimeline: { timelines[.home] },
            notificationTimeline: { timelines[.notifications] },
            isNotificationTabActive: environment.isNotificationTabActive
        )

        let coordinator = StreamingCoordinator(
            account: account,
            socketProvider: socketProvider,
            scheduler: scheduler,
            configurationProvider: configurationProvider,
            pathMonitor: pathMonitorFactory(),
            callbacks: StreamingCoordinator.Callbacks(
                stateDidChange: environment.stateDidChange,
                configurationDidLoad: environment.configurationDidLoad,
                didReceiveEvent: { [weak ingestor] event in ingestor?.ingest(event) },
                backfill: environment.backfill
            )
        )

        return AccountSession(account: account,
                              client: client,
                              timelines: timelines,
                              eventIngestor: ingestor,
                              coordinator: coordinator)
    }

    /// Builds the (empty) home / notifications timelines for a session, fetching
    /// over the session's own REST client. Mirrors the pre-refactor
    /// `constructTimelineModel` construction.
    private func makeTimelines(client: any FediverseClient) -> [TimelineType: TimelineModel] {
        let performer = environment.performer
        let focus = environment.focusPostArea

        let home = TimelineModel(focusPostArea: focus) { [weak performer] _ in
            let adaptors = try await client.fetchHomeTimeline()
            return adaptors.map { StatusModel(adaptor: $0, performer: performer) }
        }

        let notifications = TimelineModel(focusPostArea: focus) { [weak performer] _ in
            let adaptors = try await client.fetchNotifications()
            return adaptors.compactMap { NotificationModel(adaptor: $0, performer: performer) }
        }

        return [
            .home: home,
            .notifications: notifications
        ]
    }
}
