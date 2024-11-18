//
//  HapticManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import AudioToolbox
import UIKit


class HapticManager {
    static let shared = HapticManager()
    
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
