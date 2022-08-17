//
//  UIKitExtension.swift
//  Stylized
//
//  Created by Edward Wei on 18/7/2022.
//

import UIKit

/// Helper functions for the UIImage class that is useful for this sample app.
extension UIImage {

  /// Helper function to center-crop image.
  /// - Returns: Center-cropped copy of this image
  func cropCenter() -> UIImage? {
    // Don't do anything if the image is already square.
    guard size.height != size.width else {
      return self
    }
    let isPortrait = size.height > size.width
    let smallestDimension = min(size.width, size.height)
    let croppedSize = CGSize(width: smallestDimension, height: smallestDimension)
    let croppedRect = CGRect(origin: .zero, size: croppedSize)

    UIGraphicsBeginImageContextWithOptions(croppedSize, false, scale)
    let croppingOrigin = CGPoint(
      x: isPortrait ? 0 : floor((size.width - size.height) / 2),
      y: isPortrait ? floor((size.height - size.width) / 2) : 0
    )
    guard let cgImage = cgImage?.cropping(to: CGRect(origin: croppingOrigin, size: croppedSize))
    else { return nil }
    UIImage(cgImage: cgImage).draw(in: croppedRect)
    let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return croppedImage
  }

}
