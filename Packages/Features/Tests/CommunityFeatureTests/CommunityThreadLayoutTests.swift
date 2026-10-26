@testable import CommunityFeature
import CommunityService
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct CommunityThreadLayoutTests {
  @Test(arguments: [UIUserInterfaceStyle.light, .dark])
  func shortConsecutiveRepliesKeepVisibleConnections(appearance: UIUserInterfaceStyle) async throws {
    let fixture = ShortReplyFixture()
    var service = CommunityService()
    service.markRead = { _ in }
    service.reply = { target, text in await fixture.send(text, to: target) }
    service.details = { await fixture.details($0) }
    let model = makeDetailModel(post: await fixture.details(.init(id: 1, accessHash: "hash")).post,
      service: service)
    defer { model.stop() }
    await model.load()
    try await publish("пон", in: model)
    try await publish("не знал, что ссылка на юзера такая длинная", in: model)
    #expect(model.upstream.map(\.id) == [1, 2] && model.post.id == 3)
    await model.restore()
    let image = try await render(model, appearance: appearance)
    Attachment.record(image, named: "short-reply-\(appearance.rawValue).png")
    let runs = try connectorRuns(in: image, appearance: appearance)
    #expect(runs == 2, "Both ancestor avatars need a visible connection to the following post")
  }
}

private extension CommunityThreadLayoutTests {
  private func publish(_ text: String, in model: CommunityPostDetailViewModel) async throws {
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText(text)
    await composer.publish()
    #expect(composer.published != nil)
  }

  private func render(
    _ model: CommunityPostDetailViewModel, appearance: UIUserInterfaceStyle
  ) async throws -> UIImage {
    let view = CommunityPostDetailView(
      model: model, currentUser: nil, avatarURL: { _ in URL(fileURLWithPath: "/unused") },
      openAuthor: nil)
      .font(.body)
      .environment(\.dynamicTypeSize, .large)
      .environment(\.locale, Locale(identifier: "en_US"))
      .environment(\.colorScheme, appearance == .dark ? .dark : .light)
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let controller = UIHostingController(rootView: view)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: Constants.width, height: Constants.height)
    window.overrideUserInterfaceStyle = appearance
    window.rootViewController = controller
    window.isHidden = false
    defer { window.isHidden = true }
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(Constants.renderDelay))
    controller.view.layoutIfNeeded()
    let format = UIGraphicsImageRendererFormat()
    format.scale = Constants.scale
    return UIGraphicsImageRenderer(bounds: controller.view.bounds, format: format).image { _ in
      controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
  }

  private func connectorRuns(in image: UIImage, appearance: UIUserInterfaceStyle) throws -> Int {
    let pixels = try rgba(image)
    let reference = try rgba(separatorSample(appearance: appearance))
    let width = try #require(image.cgImage).width
    let height = try #require(image.cgImage).height
    let x = Int(Constants.connectorX * Constants.scale)
    var length = 0
    var runs = 0
    // Glass chrome can share the separator color; inspect only the message area.
    for y in 0..<(height * Constants.contentScanNumerator / Constants.contentScanDenominator) {
      let offset = (y * width + x) * Constants.components
      let matches = (0..<Constants.colorComponents).allSatisfy {
        abs(Int(pixels[offset + $0]) - Int(reference[$0])) <= Constants.colorTolerance
      }
      if matches { length += 1 }
      else {
        if length >= Constants.minimumRun { runs += 1 }
        length = 0
      }
    }
    return runs + (length >= Constants.minimumRun ? 1 : 0)
  }

  private func separatorSample(appearance: UIUserInterfaceStyle) -> UIImage {
    let traits = UITraitCollection(userInterfaceStyle: appearance)
    return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in
      UIColor.systemBackground.resolvedColor(with: traits).setFill()
      UIRectFillUsingBlendMode(CGRect(x: 0, y: 0, width: 1, height: 1), .normal)
      UIColor.separator.resolvedColor(with: traits).setFill()
      UIRectFillUsingBlendMode(CGRect(x: 0, y: 0, width: 1, height: 1), .normal)
    }
  }

  private func rgba(_ image: UIImage) throws -> [UInt8] {
    let image = try #require(image.cgImage)
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * Constants.components)
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    try bytes.withUnsafeMutableBytes { buffer in
      let context = try #require(CGContext(
        data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * Constants.components, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
  }
}

private actor ShortReplyFixture {
  private var texts = ["Original post with enough text to occupy several lines and show the existing connection before two short replies are sent."]

  func send(_ text: String, to target: PostDescriptor) -> PostDescriptor {
    #expect(target.id == Int64(texts.count))
    texts.append(text)
    return .init(id: Int64(texts.count), accessHash: "hash")
  }

  func details(_ descriptor: PostDescriptor) -> CommunityPostDetails {
    .init(post: post(descriptor.id), upstream: (1..<descriptor.id).map(post),
          replies: .init(data: [], nextId: nil))
  }

  private func post(_ id: Int64) -> CommunityPost {
    .published(.init(descriptor: .init(id: id, accessHash: "hash"), text: texts[Int(id - 1)],
      owner: .init(id: 7, accessHash: "owner", nickname: "Alex N"), date: .now, edited: false))
  }
}

private enum Constants {
  static let width: CGFloat = 390
  static let height: CGFloat = 900
  static let scale: CGFloat = 2
  static let connectorX: CGFloat = 36
  static let components = 4
  static let colorComponents = 3
  static let colorTolerance = 3
  static let minimumRun = 8
  static let renderDelay = 100
  static let contentScanNumerator = 2
  static let contentScanDenominator = 3
}
