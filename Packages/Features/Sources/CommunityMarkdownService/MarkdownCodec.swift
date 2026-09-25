import Foundation
import Markdown

/// Rich text editing is enabled only for AST nodes the codec can represent losslessly.
public struct MarkdownCodec: Sendable {
  public init() {}

  public func decode(_ source: String) throws -> AttributedString {
    let document = Document(parsing: source, options: [.disableSmartOpts])
    guard !requiresSourceEditing(source) else { return AttributedString(source) }
    return document.children.enumerated().reduce(into: AttributedString()) { result, entry in
      if entry.offset > 0 { result.append(AttributedString("\n\n")) }
      result.append(MarkdownDocument.inlineText(in: entry.element))
    }
  }

  public func requiresSourceEditing(_ source: String) -> Bool {
    func supported(_ node: any Markup) -> Bool {
      switch node {
      case let link as Markdown.Link:
        guard link.title == nil, let target = link.destination, let url = URL(string: target), Self.isAllowedLink(url) else { return false }
      case is Document, is Paragraph, is Markdown.Text, is Strong, is Emphasis,
           is Strikethrough, is InlineCode, is SoftBreak, is LineBreak: break
      default: return false
      }
      return node.children.allSatisfy(supported)
    }
    return !supported(Document(parsing: source, options: [.disableSmartOpts]))
  }

  public func encode(_ text: AttributedString) -> String {
    text.runs.map { run in
      let raw = String(text[run.range].characters)
      let intent = run.inlinePresentationIntent ?? []
      let leading = String(raw.prefix(while: \.isWhitespace))
      let remainder = raw.dropFirst(leading.count)
      let trailing = String(remainder.reversed().prefix(while: \.isWhitespace).reversed())
      let core = String(remainder.dropLast(trailing.count))
      guard !core.isEmpty else { return raw }
      var value = escape(core)
      if intent.contains(.code) {
        let longest = core.split(omittingEmptySubsequences: false, whereSeparator: { $0 != "`" })
          .map(\.count).max() ?? 0
        let fence = String(repeating: "`", count: longest + 1)
        value = fence + " " + core + " " + fence
      }
      if intent.contains(.emphasized) { value = "*" + value + "*" }
      if intent.contains(.stronglyEmphasized) { value = "**" + value + "**" }
      if intent.contains(.strikethrough) { value = "~~" + value + "~~" }
      if let link = run.link, Self.isAllowedLink(link) {
        let destination = link.absoluteString
          .replacingOccurrences(of: "(", with: "%28")
          .replacingOccurrences(of: ")", with: "%29")
        value = "[" + value + "](" + destination + ")"
      }
      return leading + value + trailing
    }.joined()
  }

  public static func isAllowedLink(_ url: URL) -> Bool {
    ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
  }


}

private extension MarkdownCodec {
  private func escape(_ text: String) -> String {
    let punctuation = Set("\\`*_{}[]<>()#+-.!|~>")
    return text.map { punctuation.contains($0) ? "\\\($0)" : String($0) }.joined()
  }
}
