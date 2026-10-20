@testable import CommunityEditorFeature
import CustomDump
import Dependencies
import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers

@Suite(.serialized) @MainActor struct EditorClipboardSimplificationTests {
  @Test(arguments: ["**Bold**", "*Italic*", "~~Strike~~", "`Code`", "[Link](https://example.com)"])
  func textCopyKeepsNativeFormattingAndLinks(source: String) throws {
    try preservingPasteboard {
      let editor = try mountedEditor(source)
      defer { editor.close() }
      editor.view.copy(nil)
      let copied = try nativeRichText()
      expectNoDifference(copied.string, editor.model.text.string)
      let original = editor.model.text.attributes(at: 0, effectiveRange: nil)
      let restored = copied.attributes(at: 0, effectiveRange: nil)
      expectNoDifference(EditorTextAttributes.formatBits(in: restored), EditorTextAttributes.formatBits(in: original))
      expectNoDifference(EditorLink.url(from: restored[.link]), EditorLink.url(from: original[.link]))
    }
  }

  @Test func nativeTextCutCanUndoAndKeepRichClipboard() throws {
    try preservingPasteboard {
      let source = "[**Label**](https://example.com)"
      let editor = try mountedEditor(source)
      defer { editor.close() }
      editor.view.cut(nil)
      expectNoDifference(editor.view.text, "")
      expectNoDifference(PhotoMarkdownCodec.encode(try nativeRichText()), source)
      let history = try #require(editor.view.undoManager)
      #expect(history.canUndo)
      history.undo()
      editor.model.refresh()
      expectNoDifference(editor.model.markdown, source)
    }
  }

  @Test func copyingTextBesidePhotoKeepsOnlySelectedText() throws {
    try preservingPasteboard {
      let editor = try mountedEditor("**Before**\n\n![](https://example.com/photo.jpg)\n\nAfter")
      defer { editor.close() }
      editor.view.selectedRange = NSRange(location: 0, length: 6)
      editor.view.copy(nil)
      expectNoDifference(PhotoMarkdownCodec.encode(try nativeRichText()), "**Before**")
    }
  }

  @Test func mixedPhotoCopyKeepsURLAndNeighboringFormatting() throws {
    try preservingPasteboard {
      let url = try #require(URL(string: "https://example.com/photo.jpg"))
      let editor = try mountedEditor("**Before**\n\n![cat](\(url))\n\nAfter")
      defer { editor.close() }
      let captured = try #require(editor.view.photoClipboard.captureSelection())
      editor.view.copy(nil)
      let data = try #require(UIPasteboard.general.data(forPasteboardType: PhotoFragment.typeIdentifier))
      let copied = try #require(JSONDecoder().decode(PhotoFragment.self, from: data).attributedText())
      expectNoDifference(PhotoMarkdownCodec.encode(copied), PhotoMarkdownCodec.encode(captured))
      var copiedPhotos: [PhotoAttachment] = []
      EditorTextRuns.enumerate(copied) { attributes, _ in
        if let photo = attributes[.attachment] as? PhotoAttachment { copiedPhotos.append(photo) }
      }
      expectNoDifference(copiedPhotos.map(\.sourceURL), [url])
      #expect(copiedPhotos.allSatisfy { $0.ready })
    }
  }

  @Test func inheritedAttachmentAttributeOnPlainTextDoesNotCreatePhotoRuns() throws {
    let editor = makeEditor("Text")
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder(maximumPixels: 1))
    editor.view.textStorage.addAttribute(.attachment, value: photo,
      range: NSRange(location: 0, length: editor.view.textStorage.length))
    editor.view.selectedRange = NSRange(location: 0, length: editor.view.textStorage.length)
    let captured = try #require(editor.view.photoClipboard.captureSelection())
    let restored = try #require(PhotoFragment(captured).attributedText())
    expectNoDifference(restored.string, "Text")
    #expect(restored.attribute(.attachment, at: 0, effectiveRange: nil) == nil)
  }

  @Test(arguments: 0..<16)
  func ownFragmentReconstructsMixedFormatsAndLinksAtCurrentBodySize(mask: Int) throws {
    let source = nativeRichTextWithDifferentFontSize(mask: mask)
    let data = try source.data(from: NSRange(location: 0, length: source.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let native = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd],
      documentAttributes: nil)
    let fragmentData = try #require(PhotoFragment(native).encodedData(maximumBytes: PhotoFragment.maximumEncodedBytes))
    let fragment = try JSONDecoder().decode(PhotoFragment.self, from: fragmentData)
    let combined = try #require(fragment.attributedText())
    expectNoDifference(combined.string, source.string)
    for location in [0, combined.length - 1] {
      let original = source.attributes(at: location, effectiveRange: nil)
      let attributes = combined.attributes(at: location, effectiveRange: nil)
      let bits = EditorTextAttributes.formatBits(in: original)
      expectNoDifference(EditorTextAttributes.formatBits(in: attributes), bits)
      expectNoDifference(EditorLink.url(from: attributes[.link]), EditorLink.url(from: original[.link]))
      let font = try #require(attributes[.font] as? UIFont)
      let expected = try #require(EditorTextAttributes.make(formatBits: bits)[.font] as? UIFont)
      expectNoDifference(font.pointSize, expected.pointSize)
      #expect((attributes[.foregroundColor] as? UIColor)?.isEqual(UIColor.label) == true)
    }
  }
}

private extension EditorClipboardSimplificationTests {
  private func nativeRichTextWithDifferentFontSize(mask: Int) -> NSAttributedString {
    let result = NSMutableAttributedString(string: "")
    for (index, entry) in [("Linked", mask), (" plain", 0)].enumerated() {
      let (text, bits) = entry
      var attributes = EditorTextAttributes.make(formatBits: bits)
      if let font = attributes[.font] as? UIFont {
        attributes[.font] = UIFont(descriptor: font.fontDescriptor, size: 7)
      }
      if index == 0 { attributes[.link] = URL(string: "https://example.com") }
      result.append(NSAttributedString(string: text, attributes: attributes))
    }
    return result
  }

  private func mountedEditor(_ source: String) throws -> ClipboardEditor {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let keyWindow = scene.windows.first { $0.isKeyWindow }
    let window = try #require(keyWindow)
    let editor = withDependencies { $0[EditorPhotoService.self] = .testValue } operation: { makeEditor(source) }
    editor.view.allowsEditingTextAttributes = true
    editor.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
    window.addSubview(editor.view)
    editor.view.layoutIfNeeded()
    #expect(editor.view.becomeFirstResponder())
    editor.view.selectedRange = NSRange(location: 0, length: editor.view.textStorage.length)
    return ClipboardEditor(model: editor.model, view: editor.view)
  }

  private func preservingPasteboard(_ operation: () throws -> Void) rethrows {
    let providers = UIPasteboard.general.itemProviders
    defer { UIPasteboard.general.setItemProviders(providers, localOnly: false, expirationDate: nil) }
    try operation()
  }

  private func nativeRichText() throws -> NSAttributedString {
    for (type, format) in [
      (UTType.flatRTFD.identifier, NSAttributedString.DocumentType.rtfd),
      (UTType.rtf.identifier, NSAttributedString.DocumentType.rtf)
    ] {
      if let data = UIPasteboard.general.data(forPasteboardType: type) {
        return try NSAttributedString(data: data, options: [.documentType: format], documentAttributes: nil)
      }
    }
    Issue.record("Native copy did not expose a rich text representation")
    throw CocoaError(.fileReadUnknown)
  }
}

@MainActor private struct ClipboardEditor {
  let model: CommunityEditorViewModel
  let view: PhotoTextArea

  func close() {
    model.detach()
    view.removeFromSuperview()
  }
}
