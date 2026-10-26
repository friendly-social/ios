import Foundation

extension MarkdownDocument {
  public var textSegments: [AttributedString] {
    var result: [AttributedString] = []
    _ = mappingText { result.append($0); return $0 }
    return result
  }

  public func replacingTextSegments(with text: [AttributedString]) throws -> Self {
    var index = 0
    let result = mappingText { original in
      defer { index += 1 }
      return text.indices.contains(index) ? MarkdownLinks.detecting(in: text[index]) : original
    }
    guard index == text.count else { throw TextReplacementError.countMismatch }
    return result
  }
}

private extension MarkdownDocument {
  private enum TextReplacementError: Error { case countMismatch }

  private func mappingText(_ transform: (AttributedString) -> AttributedString) -> Self {
    Self(blocks: blocks.map { Self.mappingText(in: $0, transform: transform) })
  }

  private static func mappingText(in block: Block, transform: (AttributedString) -> AttributedString) -> Block {
    let kind: Block.Kind
    switch block.kind {
    case let .paragraph(content): kind = .paragraph(mappingText(in: content, transform: transform))
    case let .heading(level, content):
      kind = .heading(level: level, content: mappingText(in: content, transform: transform))
    case let .quote(blocks): kind = .quote(blocks.map { mappingText(in: $0, transform: transform) })
    case let .list(items):
      kind = .list(items.map { item in
        ListItem(id: item.id, marker: item.marker, checked: item.checked,
          blocks: item.blocks.map { mappingText(in: $0, transform: transform) })
      })
    case let .table(table): kind = .table(mappingText(in: table, transform: transform))
    case .code, .divider, .unsupported: return block
    }
    return Block(id: block.id, kind: kind)
  }

  private static func mappingText(in content: [Inline], transform: (AttributedString) -> AttributedString) -> [Inline] {
    content.map { inline in
      guard case let .text(text) = inline.kind else { return inline }
      return Inline(id: inline.id, kind: .text(transform(text)))
    }
  }

  private static func mappingText(in table: Table, transform: (AttributedString) -> AttributedString) -> Table {
    Table(alignments: table.alignments, rows: table.rows.map { row in
      Table.Row(id: row.id, cells: row.cells.map { mappingText(in: $0, transform: transform) })
    })
  }
}
