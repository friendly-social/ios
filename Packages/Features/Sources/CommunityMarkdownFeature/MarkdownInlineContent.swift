import CommunityMarkdownService
import Foundation

struct MarkdownInlineContent: Identifiable {
  let id: Int
  let kind: MarkdownDocument.Inline.Kind

  static func make(_ content: [MarkdownDocument.Inline]) -> [Self] {
    content.enumerated().compactMap { index, inline in
      guard case let .text(text) = inline.kind else { return Self(id: inline.id, kind: inline.kind) }
      let displayed = textWithoutImageSeparators(text, at: index, in: content)
      guard !displayed.characters.isEmpty else { return nil }
      return Self(id: inline.id, kind: .text(displayed))
    }
  }
}

private extension MarkdownInlineContent {
  private static func textWithoutImageSeparators(
    _ text: AttributedString, at index: Int, in content: [MarkdownDocument.Inline]
  ) -> AttributedString {
    var text = text
    if index > 0, case .image = content[index - 1].kind, text.characters.first == "\n" {
      text = AttributedString(text[text.characters.index(after: text.startIndex)...])
    }
    if index + 1 < content.count, case .image = content[index + 1].kind, text.characters.last == "\n" {
      text = AttributedString(text[..<text.characters.index(before: text.endIndex)])
    }
    return text
  }
}
