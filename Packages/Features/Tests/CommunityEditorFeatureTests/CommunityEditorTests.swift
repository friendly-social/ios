@testable import CommunityEditorFeature
import CustomDump
import Foundation
import Testing
import UIKit

@MainActor struct CommunityEditorTests {
  @Test(arguments: 0..<16)
  func styleCombinationsStayConsistentDuringTyping(mask: Int) {
    let editor = makeEditor("")
    for format in CommunityEditorViewModel.Format.allCases where mask & format.rawValue != 0 {
      editor.model.toggle(format)
    }
    editor.view.insertText("typed")
    editor.model.refresh()
    editor.model.selectionChanged()
    for format in CommunityEditorViewModel.Format.allCases {
      #expect(editor.model.state(for: format) == (mask & format.rawValue != 0 ? .on : .off))
    }
  }

  @Test func closingEditorClearsUndoForNextOpening() {
    let editor = makeEditor("hello")
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.toggle(.bold)
    #expect(editor.model.canUndo)
    editor.model.detach()
    #expect(!editor.model.canUndo && !editor.model.canRedo)
  }

  @Test func tappingLinkEditsItsWholeFormattedLabel() throws {
    let editor = makeEditor("Before [**hello** world](https://example.com) after")
    editor.model.setSelection(NSRange(location: 7, length: 0))
    editor.model.editLink()
    let draft = try #require(editor.model.linkEdit)
    expectNoDifference(draft.title, "hello world")
    editor.model.setSelection(NSRange(location: editor.model.text.length, length: 0))
    editor.model.linkAddress = "https://getfriend.ly"
    editor.model.saveLink(draft)
    for index in 7..<18 {
      expectNoDifference(EditorLink.url(from: editor.model.text.attribute(.link, at: index, effectiveRange: nil)),
        URL(string: "https://getfriend.ly"))
    }
    expectNoDifference(editor.model.text.string, "Before hello world after")
  }

  @Test func removingLinkPreservesFormattingAndUndo() throws {
    let editor = makeEditor("[**hello**](https://example.com)")
    editor.model.setSelection(NSRange(location: 5, length: 0))
    editor.model.editLink()
    editor.model.removeLink(try #require(editor.model.linkEdit))
    expectNoDifference(editor.model.markdown, "**hello**")
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "[**hello**](https://example.com)")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, "**hello**")
  }

  @Test func repeatedURLUsesSelectedOccurrence() throws {
    let editor = makeEditor("[first](https://example.com) [second](https://example.com)")
    editor.model.setSelection(NSRange(location: 7, length: 0))
    editor.model.editLink()
    editor.model.removeLink(try #require(editor.model.linkEdit))
    expectNoDifference(editor.model.markdown, "[first](https://example.com) second")
  }

  @Test func appliedLinkDoesNotLeakIntoTyping() throws {
    let editor = makeEditor("hello")
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.editLink()
    editor.model.linkAddress = "https://example.com"
    editor.model.saveLink(try #require(editor.model.linkEdit))
    #expect(editor.view.typingAttributes[.link] == nil)
    #expect(editor.model.selection == NSRange(location: 5, length: 0))
  }

  @Test func linkButtonIsSelectedAtBothEdges() {
    let editor = makeEditor("before [hello](https://example.com) after")
    for location in [7, 12] {
      editor.model.setSelection(NSRange(location: location, length: 0))
      #expect(editor.model.isLinkSelected)
    }
  }

  @Test func untouchedSourceIsByteForBytePreserved() {
    for source in ["__bold__", "| a | b |\n|---|---|\n| x | y |", "![alt](https://example.com/a.png)"] {
      let editor = makeEditor(source)
      expectNoDifference(editor.model.markdown, source)
    }
  }

  @Test func selectionFormatsOnlySelectedText() {
    let editor = makeEditor("Hello world")
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.toggle(.bold)
    expectNoDifference(editor.model.markdown, "**Hello** world")
    #expect(editor.model.state(for: .bold) == .on)
    editor.model.toggle(.bold)
    expectNoDifference(editor.model.markdown, "Hello world")
  }

  @Test func mixedSelectionTurnsEntireRangeOn() {
    let editor = makeEditor("**Hello** world")
    editor.model.setSelection(NSRange(location: 0, length: 11))
    #expect(editor.model.state(for: .bold) == .mixed)
    editor.model.toggle(.bold)
    #expect(editor.model.state(for: .bold) == .on)
  }

  @Test func limitCountsSerializedUTF16() {
    let editor = makeEditor(String(repeating: "😀", count: 2048))
    expectNoDifference(editor.model.utf16Count, 4096)
    #expect(editor.model.canPublish)
    editor.model.setSelection(NSRange(location: 0, length: 4096))
    editor.model.toggle(.bold)
    expectNoDifference(editor.model.utf16Count, 4100)
    #expect(!editor.model.canPublish)
  }

  @Test func formattingSupportsUndoRedo() {
    let editor = makeEditor("Hello")
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.toggle(.bold)
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "Hello")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, "**Hello**")
  }

  @Test func linkWithoutSelectionInsertsEditableLabel() throws {
    let editor = makeEditor("")
    editor.model.editLink()
    editor.model.linkAddress = "https://example.com"
    editor.model.saveLink(try #require(editor.model.linkEdit))
    expectNoDifference(editor.model.text.string, "https://example.com")
    #expect(editor.view.typingAttributes[.link] == nil)
  }
}

@MainActor func makeEditor(_ source: String) -> (model: CommunityEditorViewModel, view: PhotoTextArea) {
  let model = CommunityEditorViewModel(source: source)
  let view = PhotoTextArea(usingTextLayoutManager: true)
  model.history.groupsByEvent = false
  model.attach(view)
  return (model, view)
}
