import CommunityMarkdownService
import Foundation

enum ActivityPreview {
  static func text(_ source: String) -> String {
    guard let document = try? MarkdownDocument(source: source) else { return String(source.prefix(240)) }
    return String(blocks(document.blocks).split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(240))
  }
}

private extension ActivityPreview {
  private static func blocks(_ blocks: [MarkdownDocument.Block]) -> String {
    blocks.map { block in
      switch block.kind {
      case let .paragraph(content), let .heading(_, content): inlines(content)
      case let .quote(children): self.blocks(children)
      case let .list(items): items.map { self.blocks($0.blocks) }.joined(separator: " ")
      case let .code(_, text), let .unsupported(text): text
      case let .table(table): table.rows.flatMap(\.cells).map(inlines).joined(separator: " ")
      case .divider: ""
      }
    }.joined(separator: " ")
  }

  private static func inlines(_ content: [MarkdownDocument.Inline]) -> String {
    content.map {
      switch $0.kind {
      case let .text(text): String(text.characters)
      case let .image(_, alt): alt
      }
    }.joined()
  }
}
