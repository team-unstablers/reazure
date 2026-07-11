//
//  ProfileImage.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

/// `AsyncImage` 형태의 API를 제공하되, `CachedImageLoader`(메모리 캐시 + 동일 URL 요청 병합)를
/// 백엔드로 사용하는 리모트 이미지 뷰.
///
/// `AsyncImage`와 달리:
/// - 캐시된 이미지는 첫 페인트에서 곧바로 표시합니다(ProgressView 깜빡임 없음).
/// - 뷰가 사라졌다가 다시 나타나도 캐시 히트로 즉시 복원됩니다.
/// - 로드 실패를 latch하지 않으므로, 다음 등장 시 자동으로 재시도합니다.
struct RemoteImage<Content: View, Placeholder: View>: View {
    private let url: String
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(url: String,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        // 캐시 히트 시 첫 페인트에서 곧바로 표시(ProgressView 깜빡임 방지)
        self._image = State(initialValue: CachedImageLoader.shared.getImage(url: url))
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            if let cached = CachedImageLoader.shared.getImage(url: url) {
                image = cached
                return
            }

            // 이전 URL의 이미지가 남아있지 않도록 초기화
            image = nil

            if let loaded = await CachedImageLoader.shared.loadImage(url: url) {
                image = loaded
            }
            // 실패 시 image는 nil로 유지 → 다음 등장 때 재시도(latch 없음)
        }
    }
}

/// 계정 아바타를 렌더링합니다. 로딩/캐싱은 `RemoteImage`에 위임합니다.
struct ProfileImage: View, Equatable {
    var url: String
    var size: CGFloat = 56.0
    var compact: Bool = false

    var body: some View {
        RemoteImage(url: url) { image in
            if compact {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: 24)
                    .clipped()
            } else {
                image
                    .resizable()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: 4))
            }
        } placeholder: {
            ProgressView()
                .frame(width: size, height: compact ? 24 : size)
        }
    }

    static func == (lhs: ProfileImage, rhs: ProfileImage) -> Bool {
        return lhs.url == rhs.url && lhs.size == rhs.size && lhs.compact == rhs.compact
    }
}

/// 단일 또는 이중(리블로그/관련 계정) 아바타 스택을 렌더링합니다.
///
/// `PostItem`과 `CompactPostItem`에 중복돼 있던 아바타 레이아웃을 하나로 통합합니다.
/// - `compact == false`: 큰 아바타 위에 작은 아바타를 겹쳐 표시(56pt 프레임).
/// - `compact == true`: 좌우로 24pt씩 잘라 나란히 표시.
struct ProfileImageStack: View {
    var primary: String
    var secondary: String? = nil
    var compact: Bool = false

    var body: some View {
        if compact {
            if let secondary {
                ZStack {
                    // crop left 24 pixels
                    ProfileImage(url: primary, size: 48, compact: true)
                        .equatable()
                        .clipShape(Rectangle().size(width: 24, height: 24))
                    ProfileImage(url: secondary, size: 48, compact: true)
                        .equatable()
                        .clipShape(Rectangle().size(width: 24, height: 24).offset(x: 24))
                }
            } else {
                ProfileImage(url: primary, size: 48, compact: true)
                    .equatable()
            }
        } else {
            if let secondary {
                ZStack {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(width: 56, height: 56)
                    ProfileImage(url: primary, size: 48)
                        .equatable()
                        .offset(x: -4, y: -4)
                    ProfileImage(url: secondary, size: 32)
                        .equatable()
                        .offset(x: 12, y: 12)
                }
            } else {
                ProfileImage(url: primary)
                    .equatable()
            }
        }
    }
}

#Preview {
    ProfileImage(url: "")
}
