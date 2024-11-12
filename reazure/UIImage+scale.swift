//
//  UIImage+scale.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/12/24.
//
import Foundation

import UIKit
import CoreImage

extension UIImage {
    func scale(to newSize: CGFloat) -> UIImage {
        let ciImage = CIImage(image: self)!
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        
        let scale = newSize / self.size.height

        let aspectRatio = self.size.width / self.size.height
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        
        let outputImage = filter.outputImage!
        
        let context = CIContext()
        let cgImage = context.createCGImage(outputImage, from: outputImage.extent)!
        
        return UIImage(cgImage: cgImage)
    }
}
