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
    let client: MastodonClient
    let timelines: [TimelineType: TimelineModel]

    private let eventIngestor: EventIngestor
    private let coordinator: StreamingCoordinator

    init(account: Account,
         client: MastodonClient,
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
        let backfillHome: () -> Void
    }

    private let environment: Environment

    // Streaming seams passed down to each session's `StreamingCoordinator`.
    // Injectable so the whole session lifecycle can be exercised without a network.
    private let socketProvider: WebSocketProviding
    private let scheduler: ReconnectScheduling
    private let configurationProvider: (Account) async throws -> FediverseServerConfiguration

    private(set) var current: AccountSession?

    init(environment: Environment,
         socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         scheduler: ReconnectScheduling = MainQueueReconnectScheduler(),
         configurationProvider: @escaping (Account) async throws -> FediverseServerConfiguration = { try await $0.server.configuration() }) {
        self.environment = environment
        self.socketProvider = socketProvider
        self.scheduler = scheduler
        self.configurationProvider = configurationProvider
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

    private func makeSession(for account: Account) -> AccountSession {
        let client = MastodonClient(using: account)
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
            callbacks: StreamingCoordinator.Callbacks(
                stateDidChange: environment.stateDidChange,
                configurationDidLoad: environment.configurationDidLoad,
                didReceiveEvent: { [weak ingestor] event in ingestor?.ingest(event) },
                backfillHome: environment.backfillHome
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
    private func makeTimelines(client: MastodonClient) -> [TimelineType: TimelineModel] {
        let performer = environment.performer
        let focus = environment.focusPostArea

        let home = TimelineModel(focusPostArea: focus) { [weak performer] _ in
            let statuses = try await client.homeTimeline()
            return statuses.map { StatusModel(adaptor: MastodonStatusAdaptor(from: $0), performer: performer) }
        }

        let notifications = TimelineModel(focusPostArea: focus) { [weak performer] _ in
            let notifications = try await client.notifications()
            return notifications.compactMap { NotificationModel(adaptor: MastodonNotificationAdaptor(from: $0), performer: performer) }
        }

        return [
            .home: home,
            .notifications: notifications
        ]
    }
}
