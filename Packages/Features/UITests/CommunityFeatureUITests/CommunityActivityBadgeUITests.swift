import UIKit
import XCTest

@MainActor final class CommunityActivityBadgeUITests: XCTestCase {
  func testUnreadIndicatorIsVisibleBeforeOpeningActivity() {
    assertUnreadBadge(appearance: "Light")
  }

  func testUnreadIndicatorIsVisibleInDarkAppearance() {
    assertUnreadBadge(appearance: "Dark")
  }

  func testBellHasNoUnreadIndicatorWhenBackendHasNone() {
    let app = launchFeed(hasNew: false)
    XCTAssertTrue(app.buttons["Activity"].waitForExistence(timeout: Constants.timeout))
    XCTAssertFalse(app.buttons["Activity, new notifications"].exists)
    XCTAssertFalse(containsRed(app.buttons["Activity"].screenshot()))
  }
}

private extension CommunityActivityBadgeUITests {
  private func assertUnreadBadge(appearance: String) {
    let app = launchFeed(hasNew: true, appearance: appearance)
    let bell = app.buttons["Activity, new notifications"]
    XCTAssertTrue(bell.waitForExistence(timeout: Constants.timeout))
    XCTAssertTrue(containsRed(bell.screenshot()), "The unread badge must be visible in red")
  }

  private func containsRed(_ screenshot: XCUIScreenshot) -> Bool {
    guard let image = screenshot.image.cgImage else { return false }
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * Constants.channels)
    return pixels.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(
        data: buffer.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: Constants.bitsPerChannel, bytesPerRow: image.width * Constants.channels,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return stride(from: 0, to: buffer.count, by: Constants.channels).contains { index in
        let red = Int(buffer[index])
        let green = Int(buffer[index + 1])
        let blue = Int(buffer[index + 2])
        return red > Constants.minimumRed && red - max(green, blue) > Constants.channelSeparation
      }
    }
  }

  private func launchFeed(hasNew: Bool, appearance: String = "Light") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--editor-restart-tests", "--reply-toolbar-tests", "-AppleLanguages", "(en)"]
    app.launchArguments += ["-AppleInterfaceStyle", appearance]
    if hasNew { app.launchArguments.append("--activity-badge") }
    app.launch()
    return app
  }
}

private enum Constants {
  static let timeout = 5.0
  static let channels = 4
  static let bitsPerChannel = 8
  static let minimumRed = 128
  static let channelSeparation = 32
}
