import CommunityEditorFeature
import Foundation
import SwiftUI
import Testing

@MainActor
struct CommunityEditorTests {
  @Test func closingEditorClearsUndoForNextOpening() {
    let manager = UndoManager()
    manager.groupsByEvent = false
    let first = CommunityEditorViewModel(source: "hello")
    first.selection = AttributedTextSelection(range: first.text.startIndex..<first.text.endIndex)
    manager.beginUndoGrouping()
    first.toggle(.bold, undoManager: manager)
    manager.endUndoGrouping()
    #expect(manager.canUndo)
    first.clearUndoHistory(manager)
    let reopened = CommunityEditorViewModel(source: first.markdown)
    reopened.refreshUndoAvailability(manager)
    #expect(!reopened.canUndo && !reopened.canRedo)
  }

  @Test(arguments: 0..<16)
  func styleCombinationsStayConsistentDuringTyping(mask: Int) {
    let model = CommunityEditorViewModel()
    model.selection = AttributedTextSelection(insertionPoint: model.text.startIndex)
    let formats = CommunityEditorViewModel.Format.allCases
    for (index, format) in formats.enumerated() where mask & (1 << index) != 0 {
      model.toggle(format)
    }
    model.text = AttributedString("typed", attributes: model.selection.typingAttributes(in: model.text))
    model.selection = AttributedTextSelection(insertionPoint: model.text.endIndex)
    for (index, format) in formats.enumerated() {
      #expect(model.state(for: format) == (mask & (1 << index) != 0 ? .on : .off))
    }
    for (index, format) in formats.enumerated() where mask & (1 << index) != 0 {
      model.toggle(format)
    }
    let attributes = model.selection.typingAttributes(in: model.text)
    let font = (attributes.font ?? .body).resolve(in: EnvironmentValues().fontResolutionContext)
    #expect(!font.isBold && !font.isItalic && !font.isMonospaced)
    #expect(attributes.strikethroughStyle == nil)
    #expect(attributes.inlinePresentationIntent == nil)
    for format in formats { #expect(model.state(for: format) == .off) }
  }

  @Test func tappingLinkEditsItsWholeFormattedLabel() {
    let model = CommunityEditorViewModel(source: "Before [**hello** world](https://example.com) after")
    let start = model.text.characters.index(model.text.startIndex, offsetBy: 7)
    model.selection = AttributedTextSelection(insertionPoint: start)
    model.editLink()
    #expect(model.showsLinkEditor)
    #expect(model.isEditingLink)
    #expect(model.linkAddress == "https://example.com")
    model.selection = AttributedTextSelection(insertionPoint: model.text.endIndex)
    model.linkAddress = "https://getfriend.ly"
    model.applyLink()
    #expect(model.text.runs[\.link].contains { $0.0?.absoluteString == "https://getfriend.ly" })
    #expect(!model.text.runs[\.link].contains { $0.0?.absoluteString == "https://example.com" })
    #expect(String(model.text.characters) == "Before hello world after")
  }

  @Test func removingLinkPreservesTextFormattingAndSupportsUndo() {
    let model = CommunityEditorViewModel(source: "[**hello**](https://example.com)")
    let original = model.text
    let manager = UndoManager()
    manager.groupsByEvent = false
    model.selection = AttributedTextSelection(insertionPoint: model.text.endIndex)
    model.editLink()
    manager.beginUndoGrouping()
    model.removeLink(undoManager: manager)
    manager.endUndoGrouping()
    #expect(model.markdown == "**hello**")
    #expect(!model.showsLinkEditor)
    manager.undo()
    #expect(model.text == original)
    manager.redo()
    #expect(model.markdown == "**hello**")
  }

  @Test func repeatedURLUsesSelectedOccurrence() {
    let model = CommunityEditorViewModel(source: "[first](https://example.com) [second](https://example.com)")
    let start = model.text.characters.index(model.text.startIndex, offsetBy: 7)
    model.selection = AttributedTextSelection(insertionPoint: start)
    model.editLink()
    model.removeLink()
    #expect(model.markdown == "[first](https://example.com) second")
  }

  @Test func typingAfterAppliedLinkDoesNotInheritItsURL() {
    let model = CommunityEditorViewModel(source: "hello")
    model.selection = AttributedTextSelection(range: model.text.startIndex..<model.text.endIndex)
    model.editLink()
    model.linkAddress = "https://example.com"
    model.applyLink()
    #expect(model.selection.typingAttributes(in: model.text).link == nil)
  }

  @Test func movingCursorToEndOfLinkClearsTypingURL() {
    let model = CommunityEditorViewModel(source: "[hello](https://example.com)")
    model.selection = AttributedTextSelection(insertionPoint: model.text.endIndex)
    #expect(model.isLinkSelected)
    model.stopLinkAtBoundary()
    #expect(model.selection.typingAttributes(in: model.text).link == nil)
    #expect(model.isLinkSelected)
    model.editLink()
    #expect(model.linkAddress == "https://example.com")
  }

  @Test func linkButtonIsSelectedAtBothEdges() {
    let model = CommunityEditorViewModel(source: "before [hello](https://example.com) after")
    let start = model.text.characters.index(model.text.startIndex, offsetBy: 7)
    let end = model.text.characters.index(start, offsetBy: 5)
    model.selection = AttributedTextSelection(insertionPoint: start)
    #expect(model.isLinkSelected)
    model.selection = AttributedTextSelection(insertionPoint: end)
    #expect(model.isLinkSelected)
  }

  @Test func inlineCodeButtonStaysSelectedAtCursor() {
    let model = CommunityEditorViewModel(source: "before `code` after")
    let start = model.text.characters.index(model.text.startIndex, offsetBy: 7)
    let middle = model.text.characters.index(start, offsetBy: 2)
    let end = model.text.characters.index(start, offsetBy: 4)
    model.selection = AttributedTextSelection(insertionPoint: middle)
    #expect(model.state(for: .code) == .on, "middle")
    model.selection = AttributedTextSelection(insertionPoint: end)
    #expect(model.state(for: .code) == .on, "end")
  }

  @Test func buttonsReflectAndClearTypingStyleAfterNewline() {
    let model = CommunityEditorViewModel(source: "")
    var text = AttributedString("styled\n")
    text.strikethroughStyle = .single
    model.text = text
    model.selection = AttributedTextSelection(insertionPoint: text.endIndex)
    #expect(model.state(for: .strike) == .on)
    model.toggle(.strike)
    #expect(model.state(for: .strike) == .off)
    #expect(model.selection.typingAttributes(in: model.text).strikethroughStyle == nil)
  }

  @Test func addingLinkResetsPreviousAddress() {
    let model = CommunityEditorViewModel(source: "[first](https://example.com) second")
    model.editLink()
    model.showsLinkEditor = false
    model.selection = AttributedTextSelection(insertionPoint: model.text.endIndex)
    model.editLink()
    #expect(!model.isEditingLink)
    #expect(model.linkAddress == "https://")
  }

  @Test func untouchedSourceIsByteForBytePreserved() {
    for source in ["__bold__", "| a | b |\n|---|---|\n| x | y |", "![alt](https://example.com/a.png)"] {
      let model = CommunityEditorViewModel(source: source)
      #expect(model.markdown == source)
    }
  }

  @Test func selectionFormatsOnlySelectedText() {
    let model = CommunityEditorViewModel(source: "Hello world")
    let end = model.text.characters.index(model.text.startIndex, offsetBy: 5)
    model.selection = AttributedTextSelection(range: model.text.startIndex..<end)
    model.toggle(.bold)
    #expect(model.markdown == "**Hello** world")
    #expect(model.state(for: .bold) == .on)
    model.toggle(.bold)
    #expect(model.markdown == "Hello world")
  }

  @Test func mixedSelectionTurnsEntireRangeOn() {
    let model = CommunityEditorViewModel(source: "**Hello** world")
    model.selection = AttributedTextSelection(range: model.text.startIndex..<model.text.endIndex)
    #expect(model.state(for: .bold) == .mixed)
    model.toggle(.bold)
    #expect(model.state(for: .bold) == .on)
  }

  @Test func insertionPointRetainsTypingStyle() {
    let model = CommunityEditorViewModel(source: "")
    model.selection = AttributedTextSelection(insertionPoint: model.text.startIndex)
    model.toggle(.italic)
    #expect(model.state(for: .italic) == .on)
  }

  @Test func limitCountsSerializedUTF16() {
    let model = CommunityEditorViewModel(source: String(repeating: "😀", count: 2048))
    #expect(model.utf16Count == 4096)
    #expect(model.canPublish)
    model.selection = AttributedTextSelection(range: model.text.startIndex..<model.text.endIndex)
    model.toggle(.bold)
    #expect(model.utf16Count == 4100)
    #expect(!model.canPublish)
  }

  @Test func formattingSupportsUndoAndRedo() {
    let model = CommunityEditorViewModel(source: "Hello")
    let manager = UndoManager()
    manager.groupsByEvent = false
    model.selection = AttributedTextSelection(range: model.text.startIndex..<model.text.endIndex)
    manager.beginUndoGrouping()
    model.toggle(.bold, undoManager: manager)
    manager.endUndoGrouping()
    #expect(model.markdown == "**Hello**")
    manager.undo()
    #expect(model.markdown == "Hello")
    manager.redo()
    #expect(model.markdown == "**Hello**")
  }
}
