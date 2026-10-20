@testable import CommunityEditorFeature
import CustomDump
import Foundation
import Testing
import UIKit

@Suite(.serialized) @MainActor struct EditorSimplificationTests {
  @Test func detachedEditorReleasesModelAndClearsRetainedNativeHistory() throws {
    weak var released: CommunityEditorViewModel?
    let history: UndoManager
    do {
      let editor = try makeNativeEditor()
      history = try #require(editor.view.systemUndoManager)
      history.groupsByEvent = false
      released = editor.model
      editor.model.setSelection(NSRange(location: 0, length: 5))
      editor.model.toggle(.bold)
      #expect(history.canUndo)
      editor.model.detach()
      editor.view.removeFromSuperview()
    }
    #expect(released == nil)
    #expect(!history.canUndo && !history.canRedo)
    history.undo()
    history.redo()
  }

  @Test func nativeHistoryPreservesFormattingAndPhotoUndoOrder() throws {
    let editor = try makeNativeEditor()
    defer { close(editor) }
    let history = try #require(editor.view.systemUndoManager)
    history.groupsByEvent = false
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.toggle(.bold)
    editor.model.setSelection(NSRange(location: 5, length: 0))
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/photo.jpg"),
      preview: PhotoImagePreview.placeholder(maximumPixels: 1))
    photo.ready = true
    editor.model.insertPhoto(photo)
    let source = editor.model.markdown
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "**hello**")
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "hello")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, "**hello**")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, source)
  }

  @Test func adjacentLinksKeepFirstOccurrenceAtSharedEdge() throws {
    let editor = makeEditor("[first](https://example.com/first)[second](https://example.com/second)")
    editor.model.setSelection(NSRange(location: 5, length: 0))
    editor.model.editLink()
    let draft = try #require(editor.model.linkEdit)
    expectNoDifference(draft.title, "first")
    expectNoDifference(draft.originalURL, URL(string: "https://example.com/first"))
  }

  @Test func nativeTypingAndFormattingUseTheSameHistory() throws {
    let editor = try makeNativeEditor()
    defer { close(editor) }
    let history = try #require(editor.view.systemUndoManager)
    history.groupsByEvent = false
    editor.model.setSelection(NSRange(location: 5, length: 0))
    history.beginUndoGrouping()
    editor.view.insertText(" world")
    history.endUndoGrouping()
    editor.model.refresh()
    editor.model.setSelection(NSRange(location: 0, length: 5))
    editor.model.toggle(.bold)
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "hello world")
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "hello")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, "hello world")
    editor.model.redo()
    expectNoDifference(editor.model.markdown, "**hello** world")
  }

  @Test(arguments: ["", " \n\t", "**ready**", "![](https://example.com/photo.jpg)",
    "![](friendly-photo://11111111-1111-1111-1111-111111111111)",
    "# Heading\n\n![](friendly-photo://11111111-1111-1111-1111-111111111111)",
    "`![](friendly-photo://11111111-1111-1111-1111-111111111111)`", String(repeating: "a", count: 4097)])
  func loadedAndUnloadedPublicationChecksAgree(source: String) {
    let model = CommunityEditorViewModel(source: source)
    let expected = CommunityEditorViewModel.isPublishable(source)
    expectNoDifference(model.canPublish, expected)
    model.loadSource(source)
    expectNoDifference(model.canPublish, expected)
    model.setSelection(NSRange(location: model.text.length, length: 0))
    expectNoDifference(model.canPublish, expected)
  }

  @Test func cursorMovementKeepsPendingPhotoBlockedAndRemovalUnblocksPublishing() {
    let editor = makeEditor("Before")
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder(maximumPixels: 1))
    editor.model.insertPhoto(photo)
    for position in [0, 1, editor.model.text.length] {
      editor.model.setSelection(NSRange(location: position, length: 0))
      editor.model.selectionChanged()
      #expect(!photo.ready)
      #expect(!editor.model.canPublish)
    }
    editor.model.setSelection(NSRange(location: 0, length: 1))
    editor.model.selectionChanged()
    editor.model.removePhoto()
    #expect(editor.model.photoIDs().isEmpty)
    #expect(editor.model.canPublish)
  }
}

private extension EditorSimplificationTests {
  private func makeNativeEditor() throws -> (model: CommunityEditorViewModel, view: PhotoTextArea) {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let keyWindow = scene.windows.first { $0.isKeyWindow }
    let window = try #require(keyWindow)
    let editor = makeEditor("hello")
    editor.view.frame = window.bounds
    window.addSubview(editor.view)
    editor.view.becomeFirstResponder()
    return editor
  }

  private func close(_ editor: (model: CommunityEditorViewModel, view: PhotoTextArea)) {
    editor.model.detach()
    editor.view.removeFromSuperview()
  }
}
