import Foundation
import Markdown

/// UI-independent projection of the GFM AST. No parser types cross the module boundary.
public struct MarkdownDocument: Sendable {
  public struct Block: Identifiable, Sendable {
    public let id: String
    public let kind: Kind

    public indirect enum Kind: Sendable {
      case paragraph([Inline])
      case heading(level: Int, content: [Inline])
      case quote([Block])
      case list([ListItem])
      case code(language: String?, text: String)
      case table(Table)
      case divider
      case unsupported(String)
    }
  }

  public struct Inline: Identifiable, Sendable {
    public let id: Int
    public let kind: Kind
    public enum Kind: Sendable {
      case text(AttributedString)
      case image(url: URL?, alt: String)
    }
  }

  public struct ListItem: Identifiable, Sendable {
    public let id: String
    public let marker: String
    public let checked: Bool?
    public let blocks: [Block]
  }

  public struct Table: Sendable {
    public enum Alignment: Sendable { case leading, center, trailing }
    public struct Row: Identifiable, Sendable {
      public let id: Int
      public let cells: [[Inline]]
    }
    public let alignments: [Alignment]
    public let rows: [Row]
  }

  public let blocks: [Block]

  init(blocks: [Block]) {
    self.blocks = blocks
  }

  public init(source: String) throws {
    let document = Document(parsing: source, options: [.disableSmartOpts])
    blocks = Self.blocks(in: document, path: "root")
  }

  static func inlineText(in node: any Markup) -> AttributedString {
    inlines(in: node).reduce(into: AttributedString()) { result, inline in
      if case let .text(text) = inline.kind { result.append(text) }
    }
  }
}

private extension MarkdownDocument {
  private static func inlines(in node: any Markup) -> [Inline] {
    var builder = MarkdownInlineBuilder()
    return builder.build(node)
  }

  private static func blocks(in node: any Markup, path: String) -> [Block] {
    node.children.enumerated().map { offset, child in
      let id = "\(path).\(offset)"
      let kind: Block.Kind
      switch child {
      case let paragraph as Paragraph:
        kind = .paragraph(inlines(in: paragraph))
      case let heading as Heading:
        kind = .heading(level: heading.level, content: inlines(in: heading))
      case let quote as BlockQuote:
        kind = .quote(blocks(in: quote, path: id))
      case let list as OrderedList:
        kind = .list(items(in: list, path: id, start: Int(list.startIndex)))
      case let list as UnorderedList:
        kind = .list(items(in: list, path: id, start: nil))
      case let code as CodeBlock:
        kind = .code(language: code.language, text: code.code)
      case let table as Markdown.Table:
        kind = .table(makeTable(table))
      case is ThematicBreak:
        kind = .divider
      case let html as HTMLBlock:
        kind = .unsupported(html.rawHTML)
      default:
        kind = .unsupported(child.format())
      }
      return Block(id: id, kind: kind)
    }
  }

  private static func makeTable(_ table: Markdown.Table) -> Table {
    let alignments: [Table.Alignment] = table.columnAlignments.map {
      switch $0 {
      case .center: .center
      case .right: .trailing
      default: .leading
      }
    }
    let head = Table.Row(id: 0, cells: table.head.children.map { inlines(in: $0) })
    let rows = table.body.children.enumerated().map { index, row in
      Table.Row(id: index + 1, cells: row.children.map { inlines(in: $0) })
    }
    return Table(alignments: alignments, rows: [head] + rows)
  }

  private static func items(in node: any Markup, path: String, start: Int?) -> [ListItem] {
    node.children.enumerated().compactMap { index, child in
      guard let item = child as? Markdown.ListItem else { return nil }
      let checked: Bool? = item.checkbox.map { $0 == .checked }
      let id = "\(path).\(index)"
      return ListItem(
        id: id, marker: start.map { "\($0 + index)." } ?? "•", checked: checked,
        blocks: blocks(in: item, path: id)
      )
    }
  }
}

private struct MarkdownInlineBuilder {
  typealias Inline = MarkdownDocument.Inline
  private var result: [Inline] = []
  private var pending = AttributedString()

  mutating func build(_ node: any Markup) -> [Inline] {
    for child in node.children { walk(child, attributes: AttributeContainer()) }
    flush()
    return result
  }
}

private extension MarkdownInlineBuilder {
  private static func inlineAttributes(
    for node: any Markup, inheriting attributes: AttributeContainer
  ) -> AttributeContainer {
    var attributes = attributes
    switch node {
    case is Strong:
      attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
    case is Emphasis:
      attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.emphasized)
    case is Strikethrough:
      attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.strikethrough)
    case is InlineCode:
      attributes.inlinePresentationIntent = (attributes.inlinePresentationIntent ?? []).union(.code)
    case let link as Markdown.Link:
      if let destination = link.destination, let url = URL(string: destination), MarkdownCodec.isAllowedLink(url) {
        attributes.link = url
      }
    default: break
    }
    return attributes
  }

  private mutating func flush() {
    if !pending.characters.isEmpty {
      result.append(Inline(id: result.count, kind: .text(pending)))
      pending = AttributedString()
    }
  }

  private mutating func walk(_ node: any Markup, attributes: AttributeContainer) {
    let attributes = Self.inlineAttributes(for: node, inheriting: attributes)
    switch node {
    case let image as Markdown.Image:
      flush()
      let url = image.source.flatMap(URL.init(string:)).flatMap { MarkdownCodec.isAllowedLink($0) ? $0 : nil }
      result.append(Inline(id: result.count, kind: .image(url: url, alt: image.plainText)))
      return
    case let text as Markdown.Text:
      pending.append(AttributedString(text.string, attributes: attributes))
      return
    case let code as InlineCode:
      pending.append(AttributedString(code.code, attributes: attributes))
      return
    case is SoftBreak, is LineBreak:
      pending.append(AttributedString("\n", attributes: attributes))
      return
    case let html as InlineHTML:
      pending.append(AttributedString(html.rawHTML, attributes: attributes))
      return
    default: break
    }
    for child in node.children { walk(child, attributes: attributes) }
  }
}
