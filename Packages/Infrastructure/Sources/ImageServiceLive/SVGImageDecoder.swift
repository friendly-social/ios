import Foundation
import ImageService
import Nuke
import UIKit

struct SVGImageDecoder: ImageDecoding {
  init?(context: ImageDecodingContext) {
    guard context.isCompleted else { return nil }
    let prefix = String(data: context.data.prefix(Constants.signatureBytes), encoding: .utf8)
    guard context.urlResponse?.mimeType == Constants.mimeType
      || prefix?.localizedCaseInsensitiveContains("<svg") == true else { return nil }
  }

  func decode(_ data: Data) throws -> ImageContainer {
    guard data.count <= Constants.maximumBytes, let size = SVGDimensions.read(data) else {
      throw ImageDecodingError.unknown
    }
    let svg = SVGImage(data: data, size: size)
    return ImageContainer(image: UIImage(), type: .init(rawValue: Constants.assetType), data: data,
                          userInfo: [.init(SVGImage.metadataKey): svg])
  }
}

private enum Constants {
  static let signatureBytes = 4096
  static let maximumBytes = 4 * 1024 * 1024
  static let mimeType = "image/svg+xml"
  static let assetType = "public.svg-image"
}
