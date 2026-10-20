import ImageIO
import UIKit

enum PhotoImagePreview {
  static var maximumPixels: Int { Constants.maximumPixels }

  static func decode(_ data: Data, maximumPixels: Int = Constants.maximumPixels) -> UIImage? {
    guard !data.isEmpty, maximumPixels > 0 else { return nil }
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
    let thumbnailOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixels
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    return UIImage(cgImage: image)
  }

  static func placeholder(maximumPixels: Int = Constants.maximumPixels) -> UIImage {
    let width = CGFloat(min(Constants.placeholderWidth, max(1, maximumPixels)))
    let size = CGSize(width: width, height: width * Constants.placeholderAspectRatio)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.secondarySystemBackground.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      let configuration = UIImage.SymbolConfiguration(pointSize: width * Constants.placeholderSymbolRatio)
      let symbol = UIImage(systemName: Constants.photoSymbol, withConfiguration: configuration)?
        .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
      if let symbol {
        let origin = CGPoint(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2)
        symbol.draw(at: origin)
      }
    }
  }

  static func bounded(_ image: UIImage) -> UIImage? {
    let longest = max(image.size.width, image.size.height)
    guard longest > 0 else { return nil }
    let scale = min(1, CGFloat(Constants.maximumPixels) / longest)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    return image.preparingThumbnail(of: size)
  }
}

private enum Constants {
  static let photoSymbol = "photo"
  static let placeholderSymbolRatio: CGFloat = 0.12
  static let maximumPixels = 840
  static let placeholderWidth = 560
  static let placeholderAspectRatio: CGFloat = 316 / 560
}
