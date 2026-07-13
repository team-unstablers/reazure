//
//  NotificationPresenter.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

/// Owns the presentation side effects for an incoming streaming notification:
/// unread accrual plus sound / haptic feedback.
///
/// Extracted from `SharedClient.didReceive` so the streaming decode path no
/// longer reaches directly into the `PreferencesManager`/`NotificationSound`/
/// `HapticManager` singletons and can be tested without audio or haptics. The
/// `unreadNotificationCount` itself stays a `@Published` property on the facade
/// (read by `Navbar`); this presenter only nudges it via `incrementUnread`.
final class NotificationPresenter {
    /// Injectable audio/haptic seam so tests can observe feedback without
    /// touching real devices.
    struct Effects {
        var playSound: (NotificationSound) -> Void
        var vibrate: () -> Void

        static let live = Effects(
            playSound: { $0.play() },
            vibrate: { HapticManager.shared.vibrate() }
        )
    }

    private let preferences: PreferencesManager
    private let effects: Effects
    private let incrementUnread: (Int) -> Void

    init(preferences: PreferencesManager = .shared,
         effects: Effects = .live,
         incrementUnread: @escaping (Int) -> Void) {
        self.preferences = preferences
        self.effects = effects
        self.incrementUnread = incrementUnread
    }

    /// Runs the presentation side effects for a freshly-received notification.
    /// Must be called on the main thread.
    ///
    /// - Parameter isNotificationTabActive: whether the user is currently viewing
    ///   the notifications tab. Unread is only accrued when they are not.
    func present(isNotificationTabActive: Bool) {
        if !isNotificationTabActive {
            incrementUnread(1)
        }

        playFeedback()
    }

    /// Runs the presentation side effects for a batch of notifications recovered
    /// by a REST backfill — the ones that arrived while the stream was down and
    /// which streaming will never replay. Must be called on the main thread.
    ///
    /// Unread accrues once per recovered notification, but the sound / haptic
    /// fires a single time for the whole batch: a backfill is one "you missed
    /// things while away" moment, not `count` separate arrivals, and firing per
    /// item would machine-gun the alert sound on every foreground return.
    ///
    /// - Parameter count: how many notifications the backfill newly recovered. A
    ///   batch of zero is a no-op — no unread, no feedback.
    func presentBackfill(count: Int, isNotificationTabActive: Bool) {
        guard count > 0 else {
            return
        }

        if !isNotificationTabActive {
            incrementUnread(count)
        }

        playFeedback()
    }

    /// Sound takes precedence over haptics, matching the single-notification path.
    private func playFeedback() {
        if preferences.playSoundOnNotification {
            effects.playSound(preferences.notificationSound)
        } else if preferences.vibrateOnNotification {
            effects.vibrate()
        }
    }
}
