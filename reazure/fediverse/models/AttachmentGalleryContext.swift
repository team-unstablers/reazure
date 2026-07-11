//
//  AttachmentGalleryContext.swift
//  reazure
//
//  Created by cheesekun on 7/11/26.
//

import Foundation

/// 첨부 이미지 뷰어(별도 윈도우 또는 인앱 풀스크린)로 전달하는 직렬화 가능한 컨텍스트.
///
/// `AttachmentAdaptor`는 참조 타입 프로토콜이라 `Codable`/`Hashable`을 만족하지 않으므로
/// 씬 경계를 넘길 수 없다. 뷰어에 필요한 URL만 값 타입으로 추려서 전달한다.
///
/// `WindowGroup(for:)`은 동일한 값에 대해 기존 윈도우를 재사용하므로, 같은 첨부 세트가
/// 같은 `id`(포스트 id 기반)를 갖도록 하여 중복 윈도우 생성을 방지한다.
struct AttachmentGalleryContext: Codable, Hashable, Identifiable {
    var id: String
    var items: [Item]
    var initialIndex: Int

    struct Item: Codable, Hashable, Identifiable {
        var id: String
        var previewUrl: String?
        /// 원본 우선(`origin_url`), 없으면 표준 `url`.
        var fullUrl: String
    }
}

extension AttachmentGalleryContext {
    /// 이미지 타입 첨부만 추려 갤러리 컨텍스트를 구성한다.
    ///
    /// - Parameters:
    ///   - statusId: 컨텍스트 식별자(윈도우 재사용 키)로 사용할 포스트 id.
    ///   - attachments: 포스트의 전체 첨부. 이미지 타입만 필터링된다.
    ///   - tappedId: 사용자가 탭한 첨부의 id. 필터링된 목록에서의 위치를 초기 인덱스로 잡는다.
    /// - Returns: 표시할 이미지가 하나도 없으면 `nil`.
    static func make(statusId: String,
                     attachments: [AttachmentAdaptor],
                     tappedId: String) -> AttachmentGalleryContext? {
        let items = attachments
            .filter { $0.type == "image" }
            .map { Item(id: $0.id, previewUrl: $0.previewUrl, fullUrl: $0.originUrl ?? $0.url) }

        guard !items.isEmpty else {
            return nil
        }

        let initialIndex = items.firstIndex { $0.id == tappedId } ?? 0

        return AttachmentGalleryContext(id: statusId, items: items, initialIndex: initialIndex)
    }
}
