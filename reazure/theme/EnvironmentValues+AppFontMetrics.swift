//
//  EnvironmentValues+AppFontMetrics.swift
//  reazure
//
//  Created by Gyuhwan Park on 7/11/26.
//

import SwiftUI
import UIKit

/// 앱 전역 폰트 크기 정책을 role 단위로 계산하는 리졸버.
///
/// `respectsSystemSize`가 `true`이면 현재 동작(Dynamic Type)을 그대로 재현하고,
/// `false`이면 `baseSize`(사용자 지정 pt)를 기준으로 각 role을 고정 크기로 파생한다.
/// 좁은 조절 범위(12...22)에서 예측 가능하도록 비율이 아닌 오프셋으로 파생하며,
/// `baseSize == 15`일 때 기존 픽셀값(20/12/12/11)과 정확히 일치한다.
struct AppFontMetrics: Equatable {
    var respectsSystemSize: Bool
    var baseSize: CGFloat

    private func fixed(offset: CGFloat, min lower: CGFloat) -> CGFloat {
        max(baseSize + offset, lower)
    }

    /// 본문 및 폰트 미지정 텍스트의 기준 크기.
    var body: Font {
        respectsSystemSize ? .body : .system(size: baseSize)
    }

    var caption: Font {
        respectsSystemSize ? .caption : .system(size: fixed(offset: -3, min: 10))
    }

    var caption2: Font {
        respectsSystemSize ? .caption2 : .system(size: fixed(offset: -4, min: 9))
    }

    /// Navbar 탭 아이콘. 작은 base에서도 지나치게 축소되지 않도록 하한을 둔다.
    var navbarIcon: Font {
        respectsSystemSize ? .system(size: 20) : .system(size: fixed(offset: 5, min: 17))
    }

    /// Navbar 미확인 알림 배지 숫자.
    var navbarBadge: Font {
        respectsSystemSize ? .system(size: 12) : .system(size: fixed(offset: -3, min: 10))
    }

    /// `NSAttributedString`으로 그려지는 링크 텍스트의 pt.
    /// ON에서는 본문(Dynamic Type)과 크기를 맞춰 기존 16pt 하드코딩 버그를 해소한다.
    var linkPointSize: CGFloat {
        respectsSystemSize ? UIFont.preferredFont(forTextStyle: .body).pointSize : baseSize
    }

    /// 인라인 커스텀 이모지 이미지의 렌더 높이. 본문 크기에 비례한다.
    var emojiPointSize: CGFloat {
        let base = respectsSystemSize ? UIFont.preferredFont(forTextStyle: .body).pointSize : baseSize
        return base * 1.2
    }
}

private struct AppFontMetricsKey: EnvironmentKey {
    static let defaultValue = AppFontMetrics(respectsSystemSize: true, baseSize: 15)
}

extension EnvironmentValues {
    var appFontMetrics: AppFontMetrics {
        get { self[AppFontMetricsKey.self] }
        set { self[AppFontMetricsKey.self] = newValue }
    }
}
