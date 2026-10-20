import Foundation
import UIKit
import UniformTypeIdentifiers

@MainActor final class PhotoClipboard: NSObject, UITextPasteDelegate {
  weak var view: PhotoTextArea?
  weak var model: CommunityEditorViewModel?

  func captureSelection() -> NSAttributedString? {
    guard let view, view.selectedRange.length > 0 else { return nil }
    return view.textStorage.attributedSubstring(from: view.selectedRange)
  }

  func remember(_ text: NSAttributedString?) {
    guard let text,
          let data = PhotoFragment(text).encodedData(maximumBytes: PhotoFragment.maximumEncodedBytes) else { return }
    let provider = NSItemProvider(object: text.string as NSString)
    if let richText = try? text.data(from: NSRange(location: 0, length: text.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
      provider.registerDataRepresentation(forTypeIdentifier: UTType.flatRTFD.identifier, visibility: .all) { completion in
        completion(richText, nil)
        return nil
      }
    }
    provider.registerDataRepresentation(forTypeIdentifier: PhotoFragment.typeIdentifier, visibility: .all) { completion in
      completion(data, nil)
      return nil
    }
    UIPasteboard.general.setItemProviders([provider], localOnly: false, expirationDate: nil)
  }

  func textPasteConfigurationSupporting(
    _ supporting: any UITextPasteConfigurationSupporting, transform item: any UITextPasteItem
  ) {
    guard item.itemProvider.hasItemConformingToTypeIdentifier(PhotoFragment.typeIdentifier) else {
      item.setDefaultResult()
      return
    }
    let complete: @MainActor @Sendable (Data?) -> Void = { data in
      guard let data, data.count <= PhotoFragment.maximumEncodedBytes,
            let fragment = try? JSONDecoder().decode(PhotoFragment.self, from: data),
            let text = fragment.attributedText() else {
        item.setDefaultResult()
        return
      }
      item.setResult(attributedString: text)
    }
    item.itemProvider.loadDataRepresentation(forTypeIdentifier: PhotoFragment.typeIdentifier) { data, _ in
      Task { @MainActor in complete(data) }
    }
  }

  func textPasteConfigurationSupporting(
    _ supporting: any UITextPasteConfigurationSupporting,
    combineItemAttributedStrings strings: [NSAttributedString], for range: UITextRange
  ) -> NSAttributedString {
    let result = NSMutableAttributedString(string: "")
    strings.forEach { result.append($0) }
    normalizePhotos(in: result)
    isolatePhotoParagraphs(in: result, replacing: range)
    return result
  }
}

private extension PhotoClipboard {
  private func isolatePhotoParagraphs(in result: NSMutableAttributedString, replacing range: UITextRange) {
    guard isPhotoOnly(result), let view else { return }
    let source = view.textStorage.string as NSString
    let start = view.offset(from: view.beginningOfDocument, to: range.start)
    let end = view.offset(from: view.beginningOfDocument, to: range.end)
    guard start >= 0, end >= start, end <= source.length else { return }
    let newline = NSAttributedString(string: "\n", attributes: EditorTextAttributes.make(formatBits: 0))
    if !result.string.hasPrefix("\n"), start > 0,
       source.character(at: start - 1) != Constants.lineFeed {
      result.insert(newline, at: 0)
    }
    if !result.string.hasSuffix("\n"),
       end == source.length || source.character(at: end) != Constants.lineFeed {
      result.append(newline)
    }
  }

  private func isPhotoOnly(_ text: NSAttributedString) -> Bool {
    guard text.string.contains(Constants.attachment) else { return false }
    let allowed = CharacterSet(charactersIn: Constants.attachment + "\n")
    return text.string.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  private func normalizePhotos(in result: NSMutableAttributedString) {
    var usedIDs = Set(model?.photoIDs() ?? [])
    var imported: [ObjectIdentifier: PhotoAttachment] = [:]
    let snapshot = NSAttributedString(attributedString: result)
    EditorTextRuns.enumerate(snapshot) { attributes, range in
      guard let attachment = attributes[.attachment] as? NSTextAttachment else {
        result.removeAttribute(.attachment, range: range)
        return
      }
      guard let original = resolvedPhoto(attachment, imported: &imported) else { return }
      let photo = normalized(original, usedIDs: usedIDs)
      usedIDs.insert(photo.id)
      result.addAttribute(.attachment, value: photo, range: range)
      model?.registerPastedPhoto(photo)
    }
  }

  private func normalized(_ original: PhotoAttachment, usedIDs: Set<UUID>) -> PhotoAttachment {
    guard usedIDs.contains(original.id) else { return original }
    let copy = PhotoAttachment(id: UUID(), sourceID: original.sourceID,
      sourceURL: original.sourceURL, preview: original.image)
    copy.ready = original.ready
    copy.hasLoadedPreview = original.hasLoadedPreview
    copy.alt = original.alt
    return copy
  }

  private func resolvedPhoto(
    _ attachment: NSTextAttachment, imported: inout [ObjectIdentifier: PhotoAttachment]
  ) -> PhotoAttachment? {
    if let photo = attachment as? PhotoAttachment { return photo }
    let identity = ObjectIdentifier(attachment)
    if let photo = imported[identity] { return photo }
    let data = attachment.contents ?? attachment.fileWrapper?.regularFileContents
    let image = data.flatMap { PhotoImagePreview.decode($0) }
      ?? attachment.image.flatMap(PhotoImagePreview.bounded)
    guard let image else { return nil }
    let photo = PhotoAttachment(id: UUID(), preview: image)
    imported[identity] = photo
    return photo
  }
}

private enum Constants {
  static let attachment = "\u{fffc}"
  static let lineFeed: unichar = 10
}
