import Foundation

/// A bounded render tree. Omitted images never reach the UI or start downloads.
public struct MarkdownExcerpt: Sendable {
  public let document: MarkdownDocument
  public let isTruncated: Bool

  @concurrent
  public static func prepare(source: String) async -> Self? {
    (try? MarkdownDocument(source: source)).map { Self(document: $0) }
  }

  public init(document: MarkdownDocument) {
    var budget = Budget()
    self.document = MarkdownDocument(blocks: budget.blocks(document.blocks))
    self.isTruncated = budget.truncated
  }

  private struct Budget {
    var characters = Constants.characters
    var blockCount = Constants.blocks
    var images = Constants.images
    var truncated = false

    mutating func blocks(_ source: [MarkdownDocument.Block]) -> [MarkdownDocument.Block] {
      var result: [MarkdownDocument.Block] = []
      for block in source {
        guard !truncated, blockCount > Constants.zero else { truncated = true; break }
        blockCount -= Constants.one
        let kind: MarkdownDocument.Block.Kind
        switch block.kind {
        case let .paragraph(content): kind = .paragraph(inlines(content))
        case let .heading(level, content): kind = .heading(level: level, content: inlines(content))
        case let .quote(children): kind = .quote(blocks(children))
        case let .list(items):
          kind = .list(listItems(items))
        case let .code(language, text): kind = .code(language: language, text: trim(text))
        case let .unsupported(text): kind = .unsupported(trim(text))
        case .divider: kind = .divider
        case let .table(table):
          kind = .table(visibleTable(table))
        }
        result.append(.init(id: block.id, kind: kind))
      }
      return result
    }

    private mutating func listItems(_ items: [MarkdownDocument.ListItem]) -> [MarkdownDocument.ListItem] {
      var visible: [MarkdownDocument.ListItem] = []
      for item in items {
        guard !truncated, blockCount > Constants.zero else { truncated = true; break }
        visible.append(.init(id: item.id, marker: item.marker, checked: item.checked, blocks: blocks(item.blocks)))
      }
      return visible
    }

    private mutating func visibleTable(_ table: MarkdownDocument.Table) -> MarkdownDocument.Table {
      var rows: [MarkdownDocument.Table.Row] = []
      for row in table.rows.prefix(Constants.tableRows) {
        guard !truncated else { break }
        let cells = row.cells.prefix(Constants.tableColumns).map { inlines($0) }
        rows.append(.init(id: row.id, cells: cells))
      }
      if table.rows.count > rows.count || table.rows.contains(where: { $0.cells.count > Constants.tableColumns }) { truncated = true }
      return .init(alignments: Array(table.alignments.prefix(Constants.tableColumns)), rows: rows)
    }

    mutating func inlines(_ source: [MarkdownDocument.Inline]) -> [MarkdownDocument.Inline] {
      var result: [MarkdownDocument.Inline] = []
      for inline in source {
        guard !truncated else { break }
        switch inline.kind {
        case let .text(text):
          let plain = String(text.characters)
          let prefix = trim(plain)
          let end = text.characters.index(text.startIndex, offsetBy: prefix.count)
          var visible = AttributedString(text[text.startIndex..<end])
          if truncated { visible.append(AttributedString("…")) }
          result.append(.init(id: inline.id, kind: .text(visible)))
        case .image:
          guard images > Constants.zero else { truncated = true; break }
          images -= Constants.one
          result.append(inline)
        }
      }
      return result
    }

    mutating func trim(_ text: String) -> String {
      // Permit a small overrun instead of hiding only a word or two.
      let limit = text.count <= characters + Constants.overrun ? text.count : characters
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      let prefix = String(lines.prefix(Constants.lines).joined(separator: "\n").prefix(max(Constants.zero, limit)))
      characters = max(Constants.zero, characters - prefix.count)
      if prefix.count < text.count { truncated = true }
      return prefix
    }
  }


}

private enum Constants {
  static let zero = 0
  static let one = 1
  static let characters = 400
  static let overrun = 80
  static let blocks = 5
  static let images = 1
  static let lines = 8
  static let tableRows = 3
  static let tableColumns = 4
}
