import Foundation

public struct SVGImage: Sendable {
  public static let metadataKey = "ly.getfriend.svg-image"
  public let data: Data
  public let size: CGSize

  public init(data: Data, size: CGSize) {
    self.data = data
    self.size = size
  }
}
