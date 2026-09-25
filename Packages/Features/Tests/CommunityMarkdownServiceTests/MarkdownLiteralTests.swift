import CommunityMarkdownService
import Foundation
import Testing

struct MarkdownLiteralTests {
  @Test(arguments: [
    "*hello*", "# heading", "1. item", "[name](https://example.com)",
    "![image](https://example.com/a.png)", "<script>alert(1)</script>", "&amp;",
    "a | b", "\\backtick`", "**Привет 👋**",
  ])
  func keepsSyntaxLiteral(text: String) throws {
    let source = MarkdownLiteral.encode(text)
    let document = try MarkdownDocument(source: source)
    #expect(document.blocks.count == 1)
    guard case let .paragraph(content) = document.blocks[0].kind else {
      Issue.record("Literal text became a Markdown block")
      return
    }
    #expect(content.count == 1)
    guard case let .text(value) = content[0].kind else {
      Issue.record("Literal text became Markdown formatting")
      return
    }
    #expect(String(value.characters) == text)
  }
}
