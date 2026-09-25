import CommunityMarkdownService
import Foundation
import Testing

struct MarkdownCodecTests {
  private let codec = MarkdownCodec()

  @Test(arguments: ["Привет 👨‍👩‍👧‍👦", "**жирный**", "*курсив*", "~~нет~~", "`a*b`", "[сайт](https://example.com)"])
  func inlineRoundTrip(source: String) throws {
    let first = try codec.decode(source)
    let second = try codec.decode(codec.encode(first))
    #expect(String(first.characters) == String(second.characters))
    #expect(first.runs.map(\.inlinePresentationIntent) == second.runs.map(\.inlinePresentationIntent))
    #expect(first.runs.map(\.link) == second.runs.map(\.link))
  }

  @Test(arguments: ["# Заголовок", "![alt](https://example.com/a.png)", "| a | b |\n|---|---|", "<audio src='x'>", "42. list", "---"])
  func complexSourceIsProtected(source: String) {
    #expect(codec.requiresSourceEditing(source))
  }

  @Test func unsafeLinksAreRejected() {
    #expect(!MarkdownCodec.isAllowedLink(URL(string: "javascript:alert(1)")!))
    #expect(!MarkdownCodec.isAllowedLink(URL(string: "file:///tmp/a")!))
    #expect(MarkdownCodec.isAllowedLink(URL(string: "https://example.com")!))
  }

  @Test func blockParserKeepsDistinctParagraphs() throws {
    let document = try MarkdownDocument(source: "# Title\n\nHello **world**\n\n> Quote")
    #expect(document.blocks.count == 3)
    #expect(Set(document.blocks.map(\.id)).count == 3)
    guard case .heading(level: 1, _) = document.blocks[0].kind,
          case .paragraph = document.blocks[1].kind,
          case .quote = document.blocks[2].kind else {
      Issue.record("Expected heading, paragraph and quote AST nodes")
      return
    }
  }

  @Test func literalPunctuationIsEscaped() throws {
    let literal = AttributedString("**не жирный** [не ссылка] 👋")
    #expect(String(try codec.decode(codec.encode(literal)).characters) == String(literal.characters))
  }

  @Test(arguments: ["Один\nДва\n\nТри", "a | b", "2 < 3", "\\# заголовок", "Текст -- без умных замен"])
  func plainMultilineDocumentsAreEditable(source: String) {
    #expect(!codec.requiresSourceEditing(source))
  }

  @Test func tableKeepsEmptyCellsAndAlignments() throws {
    let document = try MarkdownDocument(source: "| Name | Count |\n|:---|---:|\n| **Coffee** | 2 |\n| Tea | |")
    guard case let .table(table) = document.blocks.first?.kind else {
      Issue.record("Missing table")
      return
    }
    #expect(table.rows.count == 3)
    #expect(table.rows.allSatisfy { $0.cells.count == 2 })
    #expect(table.rows[2].cells[1].isEmpty)
    #expect(table.alignments.count == 2)
    guard case .trailing = table.alignments[1] else { Issue.record("Lost right alignment"); return }
  }

  @Test func listsKeepNestingStartNumberAndCheckboxes() throws {
    let document = try MarkdownDocument(source: "7. First\n8. Second\n\n- [x] Done\n  - Child\n- [ ] Todo")
    guard case let .list(numbered) = document.blocks[0].kind,
          case let .list(tasks) = document.blocks[1].kind else {
      Issue.record("Missing lists")
      return
    }
    #expect(numbered.map(\.marker) == ["7.", "8."])
    #expect(tasks.map(\.checked) == [true, false])
    #expect(tasks[0].blocks.count == 2)
  }

  @Test func imageDoesNotDiscardSurroundingText() throws {
    let document = try MarkdownDocument(source: "Before ![cat](https://example.com/cat.png) after")
    guard case let .paragraph(content) = document.blocks.first?.kind else { Issue.record("Missing paragraph"); return }
    #expect(content.count == 3)
    guard case let .image(url, alt) = content[1].kind else { Issue.record("Missing image"); return }
    #expect(url?.host == "example.com")
    #expect(alt == "cat")
  }

  @Test func codeRetainsLanguageAndPunctuation() throws {
    let document = try MarkdownDocument(source: "```swift\nlet a = \"**👋**\"\n```\n\n---")
    guard case let .code(language, text) = document.blocks[0].kind else { Issue.record("Missing code"); return }
    #expect(language == "swift")
    #expect(text == "let a = \"**👋**\"\n")
    guard case .divider = document.blocks[1].kind else { Issue.record("Missing divider"); return }
  }

  @Test(arguments: ["**bold *both* bold**", "*italic **both** italic*", "~~strike **bold**~~", "**a*b***", "***a*b**", "first\nsecond\n\nthird", "``a`b``", "**`code`**", "[**bold** and *italic*](https://example.com)"])
  func nestedAndMultilineRoundTrip(source: String) throws {
    let first = try codec.decode(source)
    let second = try codec.decode(codec.encode(first))
    #expect(String(first.characters) == String(second.characters))
    // Whitespace at style boundaries may be normalized; visible character styles must survive.
    func signatures(_ text: AttributedString) -> [String] {
      text.runs.flatMap { run in
        text[run.range].characters.filter { !$0.isWhitespace }.map {
          "\($0):\((run.inlinePresentationIntent ?? []).rawValue):\(run.link?.absoluteString ?? "")"
        }
      }
    }
    #expect(signatures(first) == signatures(second))
  }
}
