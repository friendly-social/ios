@testable import CommunityEditorFeature
import CustomDump
import Foundation
import Testing
import UIKit

@MainActor struct EditorPhotoFragmentTests {
  @Test func copiedPlaceholderRemainsAnUnloadedPreview() throws {
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/loading.jpg"))
    photo.ready = true
    let data = try #require(PhotoFragment(NSAttributedString(attachment: photo))
      .encodedData(maximumBytes: PhotoFragment.maximumEncodedBytes))
    let fragment = try JSONDecoder().decode(PhotoFragment.self, from: data)
    let restored = try #require(fragment.attributedText())
    let copy = try #require(restored.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    #expect(!copy.hasLoadedPreview)
    #expect(copy.ready)
    expectNoDifference(copy.sourceURL, photo.sourceURL)
  }

  @Test func nativeDuplicateKeepsAnUnloadedPreview() throws {
    let editor = makeEditor("")
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/loading.jpg"))
    photo.ready = true
    editor.model.insertPhoto(photo)
    let range = try #require(editor.view.textRange(from: editor.view.endOfDocument, to: editor.view.endOfDocument))
    let result = editor.view.photoClipboard.textPasteConfigurationSupporting(
      editor.view, combineItemAttributedStrings: [NSAttributedString(attachment: photo)], for: range)
    let copy = try #require(result.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    #expect(!copy.hasLoadedPreview)
    expectNoDifference(copy.sourceURL, photo.sourceURL)
    #expect(copy.id != photo.id)
  }

  @Test func fragmentKeepsPendingIdentityAndAltText() throws {
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    photo.alt = "my cat"
    let restored = try #require(PhotoFragment(NSAttributedString(attachment: photo)).attributedText())
    let copy = try #require(restored.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    expectNoDifference(copy.sourceID, photo.sourceID)
    expectNoDifference(copy.sourceURL, photo.sourceURL)
    expectNoDifference(copy.alt, "my cat")
    #expect(!copy.ready)
  }

  @Test func repeatedAttachmentExportsAndRestoresEveryPhoto() throws {
    let photo = readyPhoto()
    let text = NSMutableAttributedString(attachment: photo)
    text.append(NSAttributedString(attachment: photo))
    let decoded = try #require(PhotoFragment(text).attributedText())
    expectNoDifference(decoded.string, "\u{fffc}\u{fffc}")
    expectNoDifference(PhotoMarkdownCodec.encode(decoded), "![](\(photo.sourceURL))![](\(photo.sourceURL))")
  }

  @Test func photoAttributeDoesNotDiscardNeighboringText() throws {
    let photo = readyPhoto()
    var attributes = EditorTextAttributes.make(formatBits: 0)
    attributes[.attachment] = photo
    let source = NSAttributedString(string: "Before\u{fffc}After", attributes: attributes)
    let restored = try #require(PhotoFragment(source).attributedText())
    expectNoDifference(restored.string, source.string)
    #expect(restored.attribute(.attachment, at: 0, effectiveRange: nil) == nil)
    #expect(restored.attribute(.attachment, at: restored.length - 1, effectiveRange: nil) == nil)
    expectNoDifference(PhotoMarkdownCodec.encode(source), "Before![](\(photo.sourceURL))After")
  }

  @Test func smallTransferBudgetPreservesMetadata() throws {
    let photo = readyPhoto()
    let data = try #require(PhotoFragment(NSAttributedString(attachment: photo)).encodedData(maximumBytes: 1024))
    #expect(data.count <= 1024)
    let decoded = try #require(JSONDecoder().decode(PhotoFragment.self, from: data).attributedText())
    let copy = try #require(decoded.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    expectNoDifference(copy.sourceURL, photo.sourceURL)
    #expect(copy.ready)
  }

  @Test(arguments: [2049, 513]) func largeFragmentsWithinByteBudgetKeepAllPhotoURLs(count: Int) throws {
    let text = NSMutableAttributedString(string: "")
    for _ in 0..<count { text.append(NSAttributedString(attachment: readyPhoto())) }
    let data = try #require(PhotoFragment(text).encodedData(maximumBytes: PhotoFragment.maximumEncodedBytes))
    let restored = try #require(JSONDecoder().decode(PhotoFragment.self, from: data).attributedText())
    expectNoDifference(restored.string, text.string)
    for index in 0..<count {
      let original = text.attribute(.attachment, at: index, effectiveRange: nil) as? PhotoAttachment
      let copy = restored.attribute(.attachment, at: index, effectiveRange: nil) as? PhotoAttachment
      expectNoDifference(copy?.sourceURL, original?.sourceURL)
    }
  }

  @Test func portraitPhotoIsBoundedByContainerAndMaximumHeight() throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 400)).image { $0.fill(CGRect(x: 0, y: 0, width: 20, height: 400)) }
    let photo = PhotoAttachment(id: UUID(), preview: image)
    let view = PhotoTextArea(usingTextLayoutManager: true)
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 600)
    view.attributedText = NSAttributedString(attachment: photo)
    #expect(photo.image === image)
    #expect(photo.allowsTextAttachmentView && photo.usesTextAttachmentView)
    let container = NSTextContainer(size: CGSize(width: 160, height: 1000))
    let bounds = photo.displayBounds(in: container)
    #expect(bounds.width <= 150 && bounds.height <= 320)
    #expect(bounds.width >= 44)
    expectNoDifference(photo.image?.size, image.size)
  }

  @Test func photoParagraphInsertedInMiddleKeepsFormatting() throws {
    let editor = makeEditor("**BeforeAfter**")
    editor.model.setSelection(NSRange(location: 6, length: 0))
    editor.model.insertPhoto(readyPhoto())
    #expect(editor.model.text.string == "Before\n\u{fffc}\nAfter")
    #expect(EditorTextAttributes.formatBits(in: editor.model.text.attributes(at: 0, effectiveRange: nil)) == 1)
    editor.model.undo()
    expectNoDifference(editor.model.markdown, "**BeforeAfter**")
    editor.model.redo()
    #expect(editor.model.text.string == "Before\n\u{fffc}\nAfter")
  }

  @Test func sourceRoundTripKeepsMixedLocalAndRemotePhotos() {
    let id = UUID()
    let source = "**Before** ![cat](https://example.com/a.png) after\n\n![](\(PhotoAttachment.localURL(id)))"
    let decoded = PhotoMarkdownCodec.decode(source)
    expectNoDifference(PhotoMarkdownCodec.encode(decoded), source)
    #expect(PhotoMarkdownCodec.containsPendingPhotos(source))
  }

  @Test func complexImageBlocksStayProtected() {
    #expect(PhotoMarkdownCodec.requiresSourceEditing("# Title\n\n![cat](https://example.com/a.png)"))
    #expect(PhotoMarkdownCodec.requiresSourceEditing("![cat](https://example.com/a.png \"title\")"))
    #expect(!PhotoMarkdownCodec.containsPendingPhotos("`![](friendly-photo://11111111-1111-1111-1111-111111111111)`"))
  }

  @Test func dynamicTypeChangesFontSizeWithoutChangingMarkdownOrUndo() throws {
    let editor = makeEditor("**Before** and after")
    let original = editor.model.markdown
    editor.view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    let expected = UIFont.preferredFont(forTextStyle: .body, compatibleWith: editor.view.traitCollection)
    editor.model.updateFonts()
    let font = try #require(editor.model.text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
    expectNoDifference(font.pointSize, expected.pointSize)
    #expect(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    expectNoDifference(editor.model.markdown, original)
    #expect(!editor.model.history.canUndo)
  }

  @Test func changingTypingStyleDoesNotRewriteUntouchedMarkdown() {
    let editor = makeEditor("__hello__")
    editor.model.setSelection(NSRange(location: 5, length: 0))
    editor.model.toggle(.italic)
    expectNoDifference(editor.model.markdown, "__hello__")
  }
}

private extension EditorPhotoFragmentTests {
  private func readyPhoto() -> PhotoAttachment {
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/image.jpg"),
      preview: PhotoImagePreview.placeholder(maximumPixels: 1))
    photo.ready = true
    return photo
  }
}
