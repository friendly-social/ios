@testable import CommunityEditorFeature
import CustomDump
import Foundation
import Observation
import Synchronization
import Testing
import UIKit

@MainActor struct EditorDocumentStateTests {
  @Test(arguments: [false, true])
  func historyBeforeLoadingPreservesSource(redo: Bool) {
    let model = CommunityEditorViewModel(source: "__bold__")
    if redo { model.redo() } else { model.undo() }
    expectNoDifference(model.markdown, "__bold__")
    model.loadSource(model.markdown)
    expectNoDifference(model.text.string, "bold")
  }

  @Test(arguments: [("__bold__", false), ("# Heading\n\nText", true), ("- first\n- second", true)])
  func initialSourceAndModeAreAvailableBeforeLoading(source: String, sourceOnly: Bool) {
    let model = CommunityEditorViewModel(source: source)
    expectNoDifference(model.markdown, source)
    expectNoDifference(model.sourceOnly, sourceOnly)
    model.loadSource(source)
    expectNoDifference(model.markdown, source)
    expectNoDifference(model.sourceOnly, sourceOnly)
  }

  @Test(arguments: [UIUserInterfaceStyle.light, .dark])
  func typingBeforePhotoKeepsBodyFontAndAdaptiveColor(style: UIUserInterfaceStyle) throws {
    let editor = makeEditor("")
    editor.view.overrideUserInterfaceStyle = style
    let coordinator = PhotoTextView.Coordinator(editor.model)
    editor.view.delegate = coordinator
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/photo.jpg"),
                                preview: PhotoImagePreview.placeholder())
    photo.ready = true
    editor.model.insertPhoto(photo)
    editor.view.selectedRange = NSRange(location: 0, length: 0)
    editor.model.selectionChanged()
    editor.view.insertText("\n")
    editor.view.selectedRange = NSRange(location: 0, length: 0)
    editor.model.selectionChanged()
    editor.view.insertText("привет")
    let attributes = editor.view.textStorage.attributes(at: 0, effectiveRange: nil)
    let font = try #require(attributes[.font] as? UIFont)
    let color = try #require(attributes[.foregroundColor] as? UIColor)
    expectNoDifference(font.pointSize, UIFont.preferredFont(forTextStyle: .body).pointSize)
    #expect(color.resolvedColor(with: editor.view.traitCollection)
      == UIColor.label.resolvedColor(with: editor.view.traitCollection))
    withExtendedLifetime(coordinator) {}
  }

  @Test func loadingSourceUpdatesEditingModeInBothDirections() {
    let editor = makeEditor("__bold__")
    editor.model.loadSource("# Heading")
    #expect(editor.model.sourceOnly)
    expectNoDifference(editor.model.markdown, "# Heading")
    editor.model.loadSource("**hello**")
    #expect(!editor.model.sourceOnly)
    expectNoDifference(editor.model.text.string, "hello")
    expectNoDifference(editor.model.markdown, "**hello**")
    editor.model.loadSource("- first\n- second")
    #expect(editor.model.sourceOnly)
    expectNoDifference(editor.model.markdown, "- first\n- second")
  }

  @Test func selectionAndModeSwitchPreserveOriginalMarkdownSpelling() {
    let editor = makeEditor("__bold__")
    editor.model.setSelection(NSRange(location: 4, length: 0))
    editor.model.selectionChanged()
    editor.model.prepareForModeChange()
    expectNoDifference(editor.model.markdown, "__bold__")
    editor.model.setSelection(NSRange(location: 0, length: 4))
    editor.model.toggle(.bold)
    expectNoDifference(editor.model.markdown, "bold")
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "**bold**")
  }

  @Test func markdownObservationIgnoresSelectionAndReading() {
    let editor = makeEditor("hello")
    let changes = Mutex(0)
    withObservationTracking {
      _ = editor.model.markdown
    } onChange: {
      changes.withLock { $0 += 1 }
    }
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.selectionChanged()
    _ = editor.model.markdown
    expectNoDifference(changes.withLock { $0 }, 0)
    editor.model.toggle(.bold)
    expectNoDifference(changes.withLock { $0 }, 1)
    expectNoDifference(editor.model.markdown, "**hello**")
  }
}
