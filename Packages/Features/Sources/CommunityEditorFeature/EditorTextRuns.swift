import Foundation
import UIKit

/// Attribute ranges may contain several attachment characters or neighboring text.
enum EditorTextRuns {
  static func enumerate(
    _ text: NSAttributedString, using body: ([NSAttributedString.Key: Any], NSRange) -> Void
  ) {
    let source = text.string as NSString
    text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
      guard attributes[.attachment] != nil else { body(attributes, range); return }
      enumerateAttachmentRange(range, in: source, attributes: attributes, using: body)
    }
  }
}

private extension EditorTextRuns {
  private static func enumerateAttachmentRange(
    _ range: NSRange, in source: NSString, attributes: [NSAttributedString.Key: Any],
    using body: ([NSAttributedString.Key: Any], NSRange) -> Void
  ) {
    var plain = attributes
    plain.removeValue(forKey: .attachment)
    var start = range.location
    for index in range.location..<NSMaxRange(range) where source.character(at: index) == Constants.attachment {
      if index > start { body(plain, NSRange(location: start, length: index - start)) }
      body(attributes, NSRange(location: index, length: 1))
      start = index + 1
    }
    if start < NSMaxRange(range) { body(plain, NSRange(location: start, length: NSMaxRange(range) - start)) }
  }
}

private enum Constants {
  static let attachment: unichar = 0xfffc
}
