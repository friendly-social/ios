@testable import CommunityEditorFeature
import CustomDump
import Dependencies
import Testing
import UIKit

@Suite(.serialized) @MainActor struct EditorInitialLayoutTests {
  @Test func autofocusWaitsForValidBoundsAndStartsWithVisibleCursor() throws {
    let fixture = try makeEditor(autofocus: true)
    defer { fixture.close() }
    #expect(!fixture.view.isFirstResponder)
    fixture.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    fixture.view.layoutIfNeeded()
    #expect(fixture.view.isFirstResponder)
    let range = try #require(fixture.view.selectedTextRange)
    let caret = fixture.view.caretRect(for: range.end)
    #expect(fixture.view.bounds.inset(by: fixture.view.adjustedContentInset).contains(caret))
    expectNoDifference(fixture.view.selectedRange, fixture.model.selection)
  }

  @Test func shrinkingViewportKeepsRestoredCursorVisible() throws {
    let fixture = try makeEditor(autofocus: true)
    defer { fixture.close() }
    fixture.view.frame = CGRect(x: 0, y: 0, width: 320, height: 700)
    fixture.view.layoutIfNeeded()
    fixture.view.frame.size.height = 240
    fixture.view.layoutIfNeeded()
    let range = try #require(fixture.view.selectedTextRange)
    let caret = fixture.view.caretRect(for: range.end)
    #expect(fixture.view.bounds.inset(by: fixture.view.adjustedContentInset).contains(caret))
    expectNoDifference(fixture.view.selectedRange, fixture.model.selection)
  }

  @Test(arguments: [160.0, 640.0])
  func changingWidthKeepsVisibleCursorInView(width: Double) throws {
    let paragraphs = (0..<40).map { "Paragraph \($0) with enough text to wrap in a narrow editor.\n\n" }.joined()
    let fixture = try makeEditor(autofocus: true, source: paragraphs + "TARGET end")
    defer { fixture.close() }
    fixture.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    fixture.view.layoutIfNeeded()
    let selection = fixture.view.selectedRange
    fixture.view.frame.size.width = width
    fixture.view.layoutIfNeeded()
    let range = try #require(fixture.view.selectedTextRange)
    let caret = fixture.view.caretRect(for: range.end)
    #expect(fixture.view.bounds.inset(by: fixture.view.adjustedContentInset).contains(caret))
    expectNoDifference(fixture.view.selectedRange, selection)
  }

  @Test(arguments: [CGSize(width: 320, height: 230), CGSize(width: 320, height: 250),
    CGSize(width: 160, height: 240), CGSize(width: 640, height: 240)])
  func resizingWhileReadingAboveTheCursorKeepsScrollPosition(size: CGSize) throws {
    let fixture = try makeEditor(autofocus: true)
    defer { fixture.close() }
    fixture.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    fixture.view.layoutIfNeeded()
    let selection = fixture.view.selectedRange
    let top = -fixture.view.adjustedContentInset.top
    fixture.view.setContentOffset(CGPoint(x: 0, y: top), animated: false)
    fixture.view.layoutIfNeeded()
    fixture.view.frame.size = size
    fixture.view.layoutIfNeeded()
    #expect(fixture.view.contentOffset.y == top)
    expectNoDifference(fixture.view.selectedRange, selection)
  }

  @Test func topOverscrollDoesNotRevealAnOffscreenCursor() throws {
    let fixture = try makeEditor(autofocus: true)
    defer { fixture.close() }
    fixture.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    fixture.view.layoutIfNeeded()
    let selection = fixture.view.selectedRange
    let top = -fixture.view.adjustedContentInset.top
    fixture.view.setContentOffset(CGPoint(x: 0, y: top), animated: false)
    fixture.view.layoutIfNeeded()
    fixture.view.setContentOffset(CGPoint(x: 0, y: top - 80), animated: false)
    fixture.view.layoutIfNeeded()
    #expect(fixture.view.contentOffset.y <= top)
    expectNoDifference(fixture.view.selectedRange, selection)
  }
}

private extension EditorInitialLayoutTests {
  private func makeEditor(autofocus: Bool, source: String? = nil) throws -> EditorWindow {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let keyWindow = scene.windows.first { $0.isKeyWindow }
    let window = try #require(keyWindow)
    let model = withDependencies { $0[EditorPhotoService.self] = .testValue } operation: {
      CommunityEditorViewModel(source: source ?? (0..<40).map { "Paragraph \($0).\n\n" }.joined() + "TARGET end")
    }
    model.loadSource(model.markdown)
    model.restoreCursor(nil)
    let view = PhotoTextArea(usingTextLayoutManager: true)
    view.autofocus = autofocus
    model.attach(view)
    window.addSubview(view)
    return EditorWindow(model: model, view: view)
  }
}

@MainActor private struct EditorWindow {
  let model: CommunityEditorViewModel
  let view: PhotoTextArea

  func close() {
    model.detach()
    view.removeFromSuperview()
  }
}
