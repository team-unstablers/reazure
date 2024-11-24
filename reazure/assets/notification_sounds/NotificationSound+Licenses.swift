//
//  NotificationSound+Licenses.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

extension NotificationSound {
    var description: String {
        switch self {
        case .reazure:
            return "re;azure 기본 알림 소리"
        case .notify32:
            return "어째선지 그리움이 느껴지는 소리"
        case .boop:
            return "Default notification sound of Mastodon"
        default:
            return "Unknown"
        }
    }
    
    var copyright: String {
        switch self {
        case .reazure:
            "2024 Cansol (https://soundcloud.com/cansol)"
        case .notify32:
            "2024 Gyuhwan Park⭐️ (@cheesekun@ppiy.ac)"
        case .boop:
            "2017 Josef Kenny (@jk@mastodon.social)"
        default:
            "Unknown"
        }
    }
    
    var license: String {
        switch self {
        case .reazure:
            "CC0"
        case .notify32:
            "CC0"
        case .boop:
            "AGPL-3.0"
        default:
            "UNKNOWN"
        }
    }
}
