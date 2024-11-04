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
    
    init(url: String) {
        self.url = url
        self.fetchImage()
    }
    
    var didFetch = CurrentValueSubject<UIImage, Never>(UIImage())
    
    @State
    var image: UIImage = UIImage()
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: 56, height: 56)
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
