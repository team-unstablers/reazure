//
//  NotificationSounds.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

import AVFoundation

enum NotificationSound: String, Identifiable {
    private(set) static var soundIds: [NotificationSound: SystemSoundID] = [
        // https://github.com/TUNER88/iOSSystemSoundsLibrary
        .default: 1007, // <- 단, macOS에서는 재생 안됨
    ]
    
    static func initialize() {
        let sounds: [NotificationSound] = [.notify32]
        
        for sound in sounds {
            guard let url = sound.url else {
                continue
            }
            
            var soundId: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
            
            guard soundId != 0 else {
                continue
            }
            
            soundIds[sound] = soundId
        }
    }
    
    static var allCases: [NotificationSound] {
        return [.default, .notify32]
    }
    
    /// plays Tri-tone sound
    case `default` = "default"
    
    /// notify32.aif - 어째선지 그리움이 느껴지는 소리
    /// - Author: Gyuhwan Park⭐️ <unstabler@unstabler.pl>
    /// - License: CC0
    case notify32 = "notify32"
    
    var id: String {
        return self.rawValue
    }

    var url: URL? {
        switch self {
        case .notify32:
            return Bundle.main.url(forResource: "notify32", withExtension: "aif")
        default:
            return nil
        }
    }
    
    func play(_ vibrate: Bool = true) {
        if (self == .default && PlatformMask.current == .macOS) {
            // macOS에서는 tri-tone 사운드가 재생되지 않음
            NotificationSound.notify32.play()
            
            return
        }
        
        guard let soundId = Self.soundIds[self] else {
            return
        }
        
        if vibrate {
            AudioServicesPlayAlertSound(soundId)
        } else {
            AudioServicesPlaySystemSound(soundId)
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .default:
            return NSLocalizedString("NOTIFICATION_SOUND_DEFAULT", comment: "기본 (Tri-Tone)")
        case .notify32:
            return NSLocalizedString("NOTIFICATION_SOUND_NOTIFY32", comment: "notify32")
        }
    }
    
    
}
