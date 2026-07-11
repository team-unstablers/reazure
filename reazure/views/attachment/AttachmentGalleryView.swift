//
//  AttachmentGalleryView.swift
//  reazure
//
//  Created by cheesekun on 7/11/26.
//

import SwiftUI

/// 첨부 이미지 풀스크린 뷰어.
///
/// iPad/macOS에서는 별도 윈도우(`WindowGroup(for:)`)의 루트로, iPhone에서는
/// `fullScreenCover`의 콘텐츠로 동일하게 사용된다. 여러 장이면 좌우 스와이프 갤러리로 동작한다.
struct AttachmentGalleryView: View {
    let context: AttachmentGalleryContext

    @Environment(\.dismiss)
    private var dismiss

    @State private var selection: Int
    @State private var toolbarVisible: Bool = true

    init(context: AttachmentGalleryContext) {
        self.context = context
        self._selection = State(initialValue: context.initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(context.items.enumerated()), id: \.element.id) { index, item in
                    ZoomableImageView(item: item) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toolbarVisible.toggle()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: context.items.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            if toolbarVisible {
                toolbar
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!toolbarVisible)
    }

    private var toolbar: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .accessibilityLabel(Text("ATTACHMENT_VIEWER_CLOSE"))

                Spacer()

                Button {
                    saveCurrentImageToPhotos()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .accessibilityLabel(Text("ATTACHMENT_VIEWER_SAVE"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    private func saveCurrentImageToPhotos() {
        guard context.items.indices.contains(selection),
              let url = URL(string: context.items[selection].fullUrl) else {
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }

                await MainActor.run {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            } catch {
                print("[AttachmentGalleryView] Failed to save image: \(error)")
            }
        }
    }
}

/// 단일 첨부 이미지. 핀치 줌 / 팬 / 더블탭 줌 토글을 지원한다.
///
/// 페이지 스와이프(`TabView`)와의 충돌을 피하기 위해, 팬 제스처는 확대(scale > 1) 상태에서만
/// 활성화된다(`including: .none`). 축소 상태에서는 좌우 스와이프가 페이지 전환으로 넘어간다.
private struct ZoomableImageView: View {
    let item: AttachmentGalleryContext.Item
    let onSingleTap: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            RemoteImage(url: item.fullUrl) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .highPriorityGesture(magnificationGesture)
            .highPriorityGesture(panGesture(in: geometry.size), including: scale > 1 ? .all : .none)
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1 {
                        resetZoom()
                    } else {
                        scale = 2
                    }
                }
            }
            .onTapGesture(count: 1) {
                onSingleTap()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 4)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale <= 1 {
                    withAnimation(.spring()) {
                        resetZoom()
                    }
                }
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                // 이미지가 화면 밖으로 완전히 빠져나가지 않도록 이동 범위를 제한한다.
                withAnimation(.spring()) {
                    let maxX = (size.width * (scale - 1)) / 2
                    let maxY = (size.height * (scale - 1)) / 2

                    offset.width = min(max(offset.width, -maxX), maxX)
                    offset.height = min(max(offset.height, -maxY), maxY)
                    lastOffset = offset
                }
            }
    }

    private func resetZoom() {
        scale = 1
        offset = .zero
        lastOffset = .zero
    }
}
