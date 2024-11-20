//
//  ProfileImage.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI
import Combine

struct ProfileImage: View, Equatable {
    let cachedImageLoader = CachedImageLoader.shared
    
    var url: String {
        didSet {
            self.resolved = false
            self.fetchImage()
        }
    }
    
    var size: CGFloat
    
    var compact: Bool = false

    init(url: String, size: CGFloat = 56.0, compact: Bool = false) {
        self.url = url
        self.size = size
        self.compact = compact
        
        if let image = self.cachedImageLoader.getImage(url: url) {
            self.image = image
            self.resolved = true
        }
    }
    
    @State
    var image: UIImage = UIImage()
    
    @State
    var resolved: Bool = false
    
    var body: some View {
        VStack {
            if (!self.compact) {
                if self.resolved {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: 4))
                } else {
                    ProgressView()
                        .frame(width: size, height: size)
                }
            } else {
                if self.resolved {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: 24)
                        .clipped()
                } else {
                    ProgressView()
                        .frame(width: size, height: 24)
                }
            }
        }.onAppear {
            self.fetchImage()
        }
    }
    
    func fetchImage() {
        if (resolved) {
            return
        }

        print("fetching image")
        Task { [self] in
            let image = await self.cachedImageLoader.loadImage(url: url)
            // didFetch.send(image)
            
            DispatchQueue.main.async {
                self.image = image
                self.resolved = true
            }
        }
    }
    
    static func == (lhs: ProfileImage, rhs: ProfileImage) -> Bool {
        return lhs.image == rhs.image && lhs.url == rhs.url && lhs.resolved == rhs.resolved
    }
}

#Preview {
    ProfileImage(url: "")
}
