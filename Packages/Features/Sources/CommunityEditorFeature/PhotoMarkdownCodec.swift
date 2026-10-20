import CommunityMarkdownService
import Foundation
import Markdown
import UIKit

@MainActor enum PhotoMarkdownCodec {
  static func requiresSourceEditing(_ source: String) -> Bool {
    !supported(Document(parsing: source, options: [.disableSmartOpts]))
  }

  static func containsPendingPhotos(_ source: String) -> Bool {
    let document = Document(parsing: source, options: [.disableSmartOpts])
    return pending(in: document)
  }

  static func decode(_ source: String, preview: (URL) -> UIImage? = { _ in nil }) -> NSAttributedString {
    let markup = Document(parsing: source, options: [.disableSmartOpts])
    guard supported(markup), let document = try? MarkdownDocument(source: source) else {
      return NSAttributedString(string: source, attributes: EditorTextAttributes.make(formatBits: 0))
    }
    let result = NSMutableAttributedString(string: "")
    var imageURLs = images(in: markup).makeIterator()
    for (index, block) in document.blocks.enumerated() {
      if index > 0 { result.append(plain("\n\n")) }
      guard case let .paragraph(inlines) = block.kind else { continue }
      append(inlines, to: result, images: &imageURLs, preview: preview)
    }
    return result
  }

  static func encode(_ text: NSAttributedString) -> String {
    let codec = MarkdownCodec()
    var pending = AttributedString()
    var result = ""
    EditorTextRuns.enumerate(text) { attributes, range in
      if let photo = attributes[.attachment] as? PhotoAttachment {
        result += codec.encode(pending)
        pending = AttributedString()
        let destination = photo.sourceURL.absoluteString
          .replacingOccurrences(of: "(", with: "%28")
          .replacingOccurrences(of: ")", with: "%29")
        let alt = photo.alt.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
        result += "![\(alt)](\(destination))"
      } else {
        let raw = (text.string as NSString).substring(with: range)
        pending.append(textRun(raw, attributes: attributes))
      }
    }
    return result + codec.encode(pending)
  }
}

private extension PhotoMarkdownCodec {
  private static func supported(_ node: any Markup) -> Bool {
    switch node {
    case let image as Markdown.Image:
      guard image.title == nil, let value = image.source, let url = URL(string: value),
            PhotoAttachment.isValidSource(url) else { return false }
      return image.parent is Paragraph
    case let link as Markdown.Link:
      guard link.title == nil, let value = link.destination, EditorLink.url(from: value) != nil else { return false }
    case is Document, is Paragraph, is Markdown.Text, is Strong, is Emphasis,
         is Strikethrough, is InlineCode, is SoftBreak, is LineBreak: break
    default: return false
    }
    return node.children.allSatisfy(supported)
  }

  private static func pending(in node: any Markup) -> Bool {
    if let image = node as? Markdown.Image, let value = image.source,
       let url = URL(string: value), PhotoAttachment.isLocalSource(url) { return true }
    return node.children.contains { pending(in: $0) }
  }

  private static func append(
    _ inlines: [MarkdownDocument.Inline], to result: NSMutableAttributedString,
    images: inout IndexingIterator<[URL]>, preview: (URL) -> UIImage?
  ) {
    for inline in inlines {
      switch inline.kind {
      case let .text(text): result.append(editable(text))
      case let .image(url, alt):
        let original = images.next()
        guard let url = url ?? original else { continue }
        let id = PhotoAttachment.localID(url) ?? UUID()
        let photo = PhotoAttachment(id: UUID(), sourceID: id, sourceURL: url, preview: preview(url))
        photo.ready = PhotoAttachment.localID(url) == nil
        photo.alt = alt
        result.append(NSAttributedString(attachment: photo))
      }
    }
  }

  private static func images(in node: any Markup) -> [URL] {
    if let image = node as? Markdown.Image { return image.source.flatMap(URL.init(string:)).map { [$0] } ?? [] }
    return node.children.flatMap { images(in: $0) }
  }

  private static func plain(_ value: String) -> NSAttributedString {
    NSAttributedString(string: value, attributes: EditorTextAttributes.make(formatBits: 0))
  }

  private static func editable(_ text: AttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString(string: "")
    for run in text.runs {
      let intent = run.inlinePresentationIntent ?? []
      let bits = formats.reduce(0) { $0 | (intent.contains($1.1) ? $1.0.rawValue : 0) }
      var attributes = EditorTextAttributes.make(formatBits: bits)
      attributes[.link] = run.link
      result.append(NSAttributedString(string: String(text[run.range].characters), attributes: attributes))
    }
    return result
  }

  private static var formats: [(EditorTextFormat, InlinePresentationIntent)] {
    [(.bold, .stronglyEmphasized), (.italic, .emphasized), (.strike, .strikethrough), (.code, .code)]
  }

  private static func textRun(_ raw: String, attributes: [NSAttributedString.Key: Any]) -> AttributedString {
    var result = AttributedString(raw)
    let bits = EditorTextAttributes.formatBits(in: attributes)
    result.inlinePresentationIntent = formats.reduce(into: []) { intent, format in
      if bits & format.0.rawValue != 0 { intent.insert(format.1) }
    }
    result.link = EditorLink.url(from: attributes[.link])
    return result
  }
}
