import CoreGraphics
import XCTest

@MainActor final class ActivityRowUITests: XCTestCase {
  func testUnreadRowWhitespaceOpensReply() {
    openNotification(at: Constants.whitespace)
  }

  func testReadRowWhitespaceOpensReply() {
    openNotification(at: Constants.whitespace, isRead: true)
  }

  func testRowAvatarOpensReply() {
    openNotification(at: Constants.avatar)
  }

  func testRowLeadingInsetOpensReply() {
    openNotification(at: Constants.leadingInset)
  }

  func testRowTopInsetOpensReply() {
    openNotification(at: Constants.topInset)
  }
}

private extension ActivityRowUITests {
  private func openNotification(at point: CGVector, isRead: Bool = false) {
    let app = XCUIApplication()
    app.launchArguments = ["--activity-hit-area-tests", "-AppleLanguages", "(en)"]
    if isRead { app.launchArguments.append("--activity-read") }
    app.launch()
    let row = app.cells.containing(.staticText, identifier: "Hi").firstMatch
    XCTAssertTrue(row.buttons.firstMatch.waitForExistence(timeout: Constants.timeout))
    row.coordinate(withNormalizedOffset: point).tap()
    XCTAssertTrue(app.staticTexts["Opened reply"].waitForExistence(timeout: Constants.timeout))
    app.terminate()
  }
}

private enum Constants {
  static let timeout = 5.0
  static let whitespace = CGVector(dx: 0.95, dy: 0.5)
  static let avatar = CGVector(dx: 0.1, dy: 0.5)
  static let leadingInset = CGVector(dx: 0.01, dy: 0.5)
  static let topInset = CGVector(dx: 0.5, dy: 0.01)
}
