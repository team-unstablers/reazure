//
//  ProfileImage.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI
import Combine

struct ProfileImage: View {
    let cachedImageLoader = CachedImageLoader.shared
    
    var url: String {
        didSet {
            print(url)
            self.fetchImage()
        }
    }
    
    var size: CGFloat

    init(url: String, size: CGFloat = 56.0) {
        self.url = url
        self.size = size
        
        self.fetchImage()
    }
    
    var didFetch = CurrentValueSubject<UIImage, Never>(UIImage())
    
    @State
    var image: UIImage = UIImage()
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: 4))
            .onReceive(didFetch) { image in
                self.image = image
            }
    }
    
    func fetchImage() {
        Task { [self] in
            let image = await self.cachedImageLoader.loadImage(url: url)
            didFetch.send(image)
        }
    }
}

#Preview {
    ProfileImage(url: "")
}
