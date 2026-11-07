import CoreGraphics
import Foundation
@testable import PhotoViewerFeature
import SwiftUI
import Testing
import UIKit

@MainActor
struct PhotoTransitionImageTests {
  @Test func portraitAvatarFillsCircularSourceWithoutSideGaps() throws {
    let image = makePortraitImage()
    let view = PhotoTransitionImage(image: Image(uiImage: image), size: CGSize(width: 80, height: 80),
                                    cornerRadius: 40, fillsSource: true)
      .background(.black)
    let rendered = try #require(ImageRenderer(content: view).uiImage)
    #expect(try pixel(rendered, x: 40, y: 40).red > 200)
    #expect(try pixel(rendered, x: 5, y: 40).red > 200)
    #expect(try pixel(rendered, x: 0, y: 0).red < 20)
  }

  @Test func closedTransitionMatchesAvatarExactly() throws {
    let image = Image(uiImage: makePortraitImage())
    let size = CGSize(width: 80, height: 80)
    let transition = PhotoTransitionImage(image: image, size: size, cornerRadius: 40, fillsSource: true)
    let avatar = image.resizable().aspectRatio(contentMode: .fill)
      .frame(width: size.width, height: size.height).clipShape(.circle)
    let transitionImage = try #require(ImageRenderer(content: transition).uiImage)
    let avatarImage = try #require(ImageRenderer(content: avatar).uiImage)
    #expect(transitionImage.pngData() == avatarImage.pngData())
  }

  @Test func rectangularPhotoStillFitsWithoutCropping() throws {
    let image = makePortraitImage()
    let view = PhotoTransitionImage(image: Image(uiImage: image), size: CGSize(width: 80, height: 80),
                                    cornerRadius: 0, fillsSource: false)
      .background(.black)
    let rendered = try #require(ImageRenderer(content: view).uiImage)
    #expect(try pixel(rendered, x: 40, y: 40).red > 200)
    #expect(try pixel(rendered, x: 5, y: 40).red < 20)
  }
}

private extension PhotoTransitionImageTests {
  func makePortraitImage() -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
    }
  }

  func pixel(_ image: UIImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
    let cgImage = try #require(image.cgImage)
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
      data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(cgImage, in: CGRect(x: -x, y: -y, width: cgImage.width, height: cgImage.height))
    return (bytes[0], bytes[1], bytes[2])
  }
}
