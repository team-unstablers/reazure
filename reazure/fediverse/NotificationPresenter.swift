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
    private let incrementUnread: () -> Void

    init(preferences: PreferencesManager = .shared,
         effects: Effects = .live,
         incrementUnread: @escaping () -> Void) {
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
            incrementUnread()
        }

        if preferences.playSoundOnNotification {
            effects.playSound(preferences.notificationSound)
        } else if preferences.vibrateOnNotification {
            effects.vibrate()
        }
    }
}
