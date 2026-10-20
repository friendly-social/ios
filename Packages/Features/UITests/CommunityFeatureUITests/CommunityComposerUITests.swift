import XCTest

@MainActor final class CommunityComposerUITests: XCTestCase {
  func testPostToolbarSurvivesSourceSwitches() {
    let app = XCUIApplication()
    app.launchArguments = ["--editor-restart-tests", "--toolbar-tests",
      "--restart-session=" + UUID().uuidString, "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
    app.launch()
    XCTAssertTrue(app.textViews["community.richEditor"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["community.discardDraft"].waitForExistence(timeout: 3))
    assertComposerToolbarLayout(in: app)
    assertSourceSwitches(in: app, containing: "https://example.com/restart-uploaded.jpg")
  }

  func testMarkdownEditRestoresCursorAtEndAfterReopening() {
    let app = XCUIApplication()
    app.launchArguments = ["--editor-restart-tests", "--editor-reopen-tests", "--cursor-tests",
      "--restart-session=" + UUID().uuidString]
    app.launch()
    let open = app.buttons["editor.open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()
    XCTAssertTrue(app.textViews["community.richEditor"].waitForExistence(timeout: 5))
    app.buttons["Markdown"].tap()
    let source = app.textViews["community.markdownEditor"]
    XCTAssertTrue(source.waitForExistence(timeout: 3))
    source.tap()
    source.typeText(" Markdown edit ")
    app.buttons["community.closeComposer"].tap()
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()
    let editor = app.textViews["community.richEditor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    editor.typeText("CURSOREND")
    app.buttons["Markdown"].tap()
    XCTAssertTrue(source.waitForExistence(timeout: 3))
    XCTAssertTrue((source.value as? String)?.hasSuffix("CURSOREND") == true, source.value as? String ?? "")
  }

  func testReplyUsesComposerToolbarAndKeepsDraftWhenClosed() {
    let app = launchReplyEditor()
    let editor = app.textViews["community.richEditor"]
    editor.typeText("Reply draft")
    assertComposerToolbarLayout(in: app)
    assertSourceSwitches(in: app, containing: "Reply draft")
    app.buttons["community.closeComposer"].tap()
    let expand = app.buttons["Open full editor"]
    XCTAssertTrue(expand.waitForExistence(timeout: 5))
    expand.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    XCTAssertTrue((editor.value as? String)?.contains("Reply draft") == true)
    assertComposerToolbarLayout(in: app)
  }

  func testReplyDiscardRemovesDraftBeforeReopening() {
    let app = launchReplyEditor()
    let editor = app.textViews["community.richEditor"]
    editor.typeText("Discard this reply")
    app.buttons["community.discardDraft"].tap()
    let remove = app.buttons["Delete"].firstMatch
    XCTAssertTrue(remove.waitForExistence(timeout: 3))
    remove.tap()
    let expand = app.buttons["Open full editor"]
    XCTAssertTrue(expand.waitForExistence(timeout: 5))
    expand.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    XCTAssertEqual(editor.value as? String, "")
    XCTAssertFalse(app.buttons["community.publish"].isEnabled)
  }

  func testReplySubmissionReturnsToDiscussion() {
    let app = launchReplyEditor()
    let editor = app.textViews["community.richEditor"]
    editor.typeText("Sent reply")
    app.buttons["community.publish"].tap()
    let sent = app.staticTexts["Sent reply"].firstMatch
    XCTAssertTrue(sent.waitForExistence(timeout: 10))
    XCTAssertFalse(editor.exists)
  }
}

private extension CommunityComposerUITests {
  private func assertSourceSwitches(in app: XCUIApplication, containing fragment: String) {
    for _ in 0..<3 {
      app.buttons["Markdown"].tap()
      let source = app.textViews["community.markdownEditor"]
      XCTAssertTrue(source.waitForExistence(timeout: 3))
      XCTAssertTrue((source.value as? String)?.contains(fragment) == true)
      app.segmentedControls.firstMatch.buttons.element(boundBy: 0).tap()
      XCTAssertTrue(app.textViews["community.richEditor"].waitForExistence(timeout: 3))
      assertComposerToolbarLayout(in: app)
    }
  }

  private func launchReplyEditor() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--editor-restart-tests", "--reply-toolbar-tests",
      "--restart-session=" + UUID().uuidString, "-AppleLanguages", "(en)"]
    app.launch()
    let reply = app.buttons["Open post"].firstMatch
    XCTAssertTrue(reply.waitForExistence(timeout: 10))
    reply.tap()
    let expand = app.buttons["Open full editor"]
    XCTAssertTrue(expand.waitForExistence(timeout: 5))
    expand.tap()
    XCTAssertTrue(app.textViews["community.richEditor"].waitForExistence(timeout: 5))
    return app
  }
}

extension XCTestCase {
  @MainActor func assertComposerToolbarLayout(in app: XCUIApplication) {
    let navigation = app.navigationBars.containing(.button, identifier: "community.closeComposer").firstMatch
    let close = navigation.buttons["community.closeComposer"]
    let discard = navigation.buttons["community.discardDraft"]
    let undo = navigation.buttons["community.editorUndo"]
    let redo = navigation.buttons["community.editorRedo"]
    let send = navigation.buttons["community.publish"]
    XCTAssertTrue(close.exists && discard.exists && undo.exists && redo.exists)
    XCTAssertLessThan(close.frame.midX, discard.frame.midX)
    XCTAssertLessThan(discard.frame.midX, app.frame.midX)
    XCTAssertGreaterThan(undo.frame.midX, app.frame.midX)
    XCTAssertLessThan(undo.frame.midX, redo.frame.midX)
    XCTAssertEqual(undo.frame.midY, redo.frame.midY, accuracy: 1)
    XCTAssertTrue(send.exists)
    XCTAssertLessThan(redo.frame.maxX, send.frame.minX)
    XCTAssertEqual(app.buttons.matching(identifier: "community.editorUndo").count, 1)
    XCTAssertEqual(app.buttons.matching(identifier: "community.editorRedo").count, 1)
  }
}
