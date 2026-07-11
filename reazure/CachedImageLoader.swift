//
//  AccountManager.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import Foundation

import UIKit

import Alamofire
import AlamofireImage

/// 리모트 이미지(아바타/첨부/커스텀 이모지)를 로드하고 메모리 캐시에 보관합니다.
///
/// AlamofireImage의 `ImageDownloader`를 사용하여 동일 URL에 대한 동시 요청을 자동으로
/// 병합하고, 성공한 이미지를 내부 `AutoPurgingImageCache`(메모리 전용)에 저장합니다.
/// 스트리밍 전용/무영속 설계에 맞춰 디스크 캐시는 두지 않습니다.
class CachedImageLoader {
    static let shared = CachedImageLoader()

    private let imageCache = AutoPurgingImageCache()
    private let downloader: ImageDownloader

    init() {
        let downloader = ImageDownloader(
            configuration: ImageDownloader.defaultURLSessionConfiguration(),
            downloadPrioritization: .fifo,
            maximumActiveDownloads: 4,
            imageCache: imageCache
        )
        // 이미지를 scale 1.0으로 디코드합니다. (size가 픽셀 크기와 일치)
        // 기본값은 화면 배율(예: 3.0)이며, 그 경우 UIImage.size가 축소되어
        // `UIImage.scale(to:)`(포인트 기준 계산)에 의존하는 커스텀 이모지가 커집니다.
        downloader.imageResponseSerializer = ImageResponseSerializer(imageScale: 1)
        self.downloader = downloader
    }

    /// 캐시에 이미 존재하는 이미지를 동기적으로 반환합니다. (없으면 nil)
    func getImage(url: String) -> UIImage? {
        guard let request = urlRequest(for: url) else {
            return nil
        }

        return imageCache.image(for: request, withIdentifier: nil)
    }

    /// 이미지를 비동기로 로드합니다. 캐시에 있으면 즉시 반환하고, 없으면 다운로드합니다.
    ///
    /// 실패 시 빈 이미지가 아니라 `nil`을 반환하며 캐시에 저장하지 않습니다.
    /// 따라서 호출자는 실패를 구분하여 이후 재시도할 수 있습니다.
    func loadImage(url: String) async -> UIImage? {
        guard let request = urlRequest(for: url) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            downloader.download(request) { response in
                continuation.resume(returning: try? response.result.get())
            }
        }
    }

    private func urlRequest(for url: String) -> URLRequest? {
        guard let url = URL(string: url) else {
            return nil
        }

        return URLRequest(url: url)
    }
}
