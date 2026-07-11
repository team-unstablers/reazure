//
//  NotificationPresenterTests.swift
//  reazureTests
//
//  Regression coverage for `NotificationPresenter` (roadmap step 2.5). The
//  notification presentation side effects — unread accrual and sound/haptic —
//  were extracted out of `SharedClient.didReceive` so they can be exercised
//  without audio, haptics, or the shared preferences singleton.
//

import Testing

@testable import reazure

@MainActor
struct NotificationPresenterTests {

    /// Captures the feedback the presenter routes through the injectable seam.
    private final class EffectSpy {
        var playedSounds: [NotificationSound] = []
        var vibrateCount = 0

        var effects: NotificationPresenter.Effects {
            NotificationPresenter.Effects(
                playSound: { self.playedSounds.append($0) },
                vibrate: { self.vibrateCount += 1 }
            )
        }
    }

    private func preferences(playSound: Bool, vibrate: Bool, sound: NotificationSound = .default) -> PreferencesManager {
        let prefs = PreferencesManager()
        prefs.playSoundOnNotification = playSound
        prefs.vibrateOnNotification = vibrate
        prefs.notificationSound = sound
        return prefs
    }

    // MARK: - unread accrual

    @Test func present_whileNotViewingNotifications_accruesUnread() {
        var unread = 0
        let presenter = NotificationPresenter(
            preferences: preferences(playSound: false, vibrate: false),
            effects: EffectSpy().effects,
            incrementUnread: { unread += 1 }
        )

        presenter.present(isNotificationTabActive: false)

        #expect(unread == 1)
    }

    @Test func present_whileViewingNotifications_doesNotAccrueUnread() {
        var unread = 0
        let presenter = NotificationPresenter(
            preferences: preferences(playSound: false, vibrate: false),
            effects: EffectSpy().effects,
            incrementUnread: { unread += 1 }
        )

        presenter.present(isNotificationTabActive: true)

        #expect(unread == 0)
    }

    // MARK: - sound / haptic branching

    @Test func present_whenSoundEnabled_playsConfiguredSoundAndNotVibrate() {
        let spy = EffectSpy()
        let presenter = NotificationPresenter(
            preferences: preferences(playSound: true, vibrate: true, sound: .reazure),
            effects: spy.effects,
            incrementUnread: {}
        )

        presenter.present(isNotificationTabActive: false)

        #expect(spy.playedSounds == [.reazure])
        #expect(spy.vibrateCount == 0)
    }

    @Test func present_whenSoundDisabledButVibrateEnabled_vibratesOnly() {
        let spy = EffectSpy()
        let presenter = NotificationPresenter(
            preferences: preferences(playSound: false, vibrate: true),
            effects: spy.effects,
            incrementUnread: {}
        )

        presenter.present(isNotificationTabActive: false)

        #expect(spy.playedSounds.isEmpty)
        #expect(spy.vibrateCount == 1)
    }

    @Test func present_whenBothDisabled_emitsNoFeedback() {
        let spy = EffectSpy()
        let presenter = NotificationPresenter(
            preferences: preferences(playSound: false, vibrate: false),
            effects: spy.effects,
            incrementUnread: {}
        )

        presenter.present(isNotificationTabActive: false)

        #expect(spy.playedSounds.isEmpty)
        #expect(spy.vibrateCount == 0)
    }
}
