@testable import ActivityFeature
import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import PushRegistrationService
import SwiftUI
import Testing
import UIKit

@MainActor @Suite(.serialized)
struct ActivityBannerLayoutTests {
  @Test(arguments: ActivityLoadingOutcome.allCases, [UIUserInterfaceStyle.light, .dark])
  private func finishingActivityDoesNotMoveTheBannerOrChangeTheBackground(
    outcome: ActivityLoadingOutcome,
    appearance: UIUserInterfaceStyle
  ) async throws {
    let gate = ActivityLoadingGate()
    let model = makeModel(gate: gate)
    await model.refreshNotificationAuthorization()
    let window = try makeWindow(model: model, appearance: appearance)
    let controller = try #require(window.rootViewController)
    defer { window.isHidden = true }
    await gate.waitForRequest()
    let loading = try await measure(controller, name: "activity-loading.png")
    await gate.finish(outcome)
    while model.isLoading { await Task.yield() }
    let loaded = try await measure(controller, name: "activity-loaded.png")
    #expect(loading.frame == loaded.frame)
    #expect(loading.background == loaded.background)
  }
}

private extension ActivityBannerLayoutTests {
  private func makeWindow(
    model: ActivityViewModel,
    appearance: UIUserInterfaceStyle
  ) throws -> UIWindow {
    let controller = UIHostingController(rootView: ActivityView(model: model))
    controller.safeAreaRegions = []
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: Constants.width, height: Constants.height)
    window.overrideUserInterfaceStyle = appearance
    window.rootViewController = controller
    window.isHidden = false
    return window
  }

  private func makeModel(gate: ActivityLoadingGate) -> ActivityViewModel {
    withDependencies {
      $0.date.now = Constants.date
      $0[CommunityProfileService.self].currentSession = {
        .init(accountID: 7, token: "test", sessionID: "session")
      }
      $0[CommunityProfileService.self].isCurrentSession = { _ in true }
      $0[ActivityService.self].list = { _, _ in try await gate.request() }
      $0[ActivityService.self].acknowledgeUnreads = { _ in }
      $0[PushRegistrationService.self].authorizationStatus = { .notDetermined }
    } operation: { ActivityViewModel(onUnauthorized: {}) }
  }

  private func measure(
    _ controller: UIViewController,
    name: String
  ) async throws -> BannerMeasurement {
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(Constants.settleDelay))
    controller.view.layoutIfNeeded()
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(bounds: controller.view.bounds, format: format).image { _ in
      controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
    Attachment.record(image, named: name)
    return try measurement(image)
  }

  private func measurement(_ snapshot: UIImage) throws -> BannerMeasurement {
    let image = try #require(snapshot.cgImage)
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    try bytes.withUnsafeMutableBytes { buffer in
      let context = try #require(
        CGContext(
          data: buffer.baseAddress,
          width: image.width,
          height: image.height,
          bitsPerComponent: 8,
          bytesPerRow: image.width * 4,
          space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      )
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return scan(bytes, width: image.width, height: image.height)
  }

  private func scan(_ bytes: [UInt8], width: Int, height: Int) -> BannerMeasurement {
    var bounds = CGRect.null
    for y in 0..<height {
      for x in 0..<width {
        let index = (y * width + x) * 4
        let red = Int(bytes[index])
        let green = Int(bytes[index + 1])
        let blue = Int(bytes[index + 2])
        if green > 170 || green < 50, red > green + 12, blue > green + 3 {
          bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
        }
      }
    }
    #expect(!bounds.isNull)
    let offset = ((height / 2) * width + Constants.backgroundX) * 4
    return BannerMeasurement(frame: bounds, background: Array(bytes[offset..<(offset + 3)]))
  }
}

private struct BannerMeasurement {
  let frame: CGRect
  let background: [UInt8]
}

private actor ActivityLoadingGate {
  private var continuation: CheckedContinuation<ActivityPage, any Error>?
}

private extension ActivityLoadingGate {
  func request() async throws -> ActivityPage {
    try await withCheckedThrowingContinuation { continuation = $0 }
  }

  func waitForRequest() async {
    while continuation == nil { await Task.yield() }
  }

  func finish(_ outcome: ActivityLoadingOutcome) {
    switch outcome {
    case .loaded:
      let owner = CommunityPost.Owner(id: 9, accessHash: "hash", nickname: "Fixture")
      let event = ActivityEvent(
        id: 1,
        date: Constants.date,
        isRead: false,
        content: .friendRequest(from: owner)
      )
      continuation?.resume(returning: ActivityPage(events: [event], nextID: nil))
    case .empty:
      continuation?.resume(returning: ActivityPage(events: [], nextID: nil))
    case .failure:
      continuation?.resume(throwing: ActivityError.unavailable)
    }
    continuation = nil
  }
}

private enum ActivityLoadingOutcome: CaseIterable {
  case loaded, empty, failure
}

private enum Constants {
  static let width: CGFloat = 390
  static let height: CGFloat = 700
  static let settleDelay = 200
  static let backgroundX = 2
  static let date = Date(timeIntervalSince1970: 1_794_528_000)
}
