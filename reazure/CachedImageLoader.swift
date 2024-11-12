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

class CachedImageLoader {
    static let shared = CachedImageLoader()
    
    var imageCache = AutoPurgingImageCache()
    
    func loadImage(url: String) async -> UIImage {
        if let image = imageCache.image(withIdentifier: url) {
            print("cache hit")
            return image
        }
        
        let response = await AF.request(url).serializingImage(imageScale: 1).response
        
        if let image = try? response.result.get() {
            imageCache.add(image, withIdentifier: url)
            return image
        }
        
        return UIImage()
    }
}
