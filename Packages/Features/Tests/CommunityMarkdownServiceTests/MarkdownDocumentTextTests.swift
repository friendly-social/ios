import CommunityMarkdownService
import CustomDump
import Foundation
import Testing

struct MarkdownDocumentTextTests {
  @Test func exposesPreparedAttributedTextWithoutSplittingInlineFormatting() throws {
    let document = try MarkdownDocument(source: "I **used to work** here, but I *don't work here anymore*. Run `git status`.")
    let text = try #require(document.textSegments.first)
    expectNoDifference(document.textSegments.count, 1)
    expectNoDifference(String(text.characters), "I used to work here, but I don't work here anymore. Run git status.")
    #expect(text.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.stronglyEmphasized) })
    #expect(text.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.emphasized) })
    #expect(text.runs.contains { ($0.inlinePresentationIntent ?? []).contains(.code) })
  }

  @Test func preservesImagesAndNestedBlockStructureWhenReplacingPreparedText() throws {
    let document = try MarkdownDocument(source: "# Hello\n\n> Hello\n\n- Hello\n\n![cat](https://example.com/cat.png)\n\n```swift\nprint(1)\n```")
    expectNoDifference(document.textSegments.map { String($0.characters) }, ["Hello", "Hello", "Hello"])
    let result = try document.replacingTextSegments(with: Array(repeating: AttributedString("Привет"), count: 3))
    expectNoDifference(result.blocks.map(\.id), document.blocks.map(\.id))
    guard case let .heading(level, content) = result.blocks[0].kind,
          case let .quote(quote) = result.blocks[1].kind,
          case let .list(items) = result.blocks[2].kind,
          case let .paragraph(images) = result.blocks[3].kind,
          case let .image(url, alt) = images[0].kind,
          case let .code(language, code) = result.blocks[4].kind else {
      Issue.record("Replacing text changed the document structure")
      return
    }
    expectNoDifference(level, 1)
    expectNoDifference(content[0].id, 0)
    expectNoDifference(quote.map(\.id), ["root.1.0"])
    expectNoDifference(items[0].marker, "•")
    expectNoDifference(url?.absoluteString, "https://example.com/cat.png")
    expectNoDifference(alt, "cat")
    expectNoDifference(language, "swift")
    expectNoDifference(code, "print(1)\n")
  }

  @Test func replacesTableCellsWithoutLosingRowIdentityOrAlignment() throws {
    let document = try MarkdownDocument(source: "| Name | Value |\n|:---|---:|\n| First | Second |")
    let text = ["Имя", "Значение", "Первое", "Второе"].map { AttributedString($0) }
    let result = try document.replacingTextSegments(with: text)
    expectNoDifference(result.textSegments, text)
    guard case let .table(table) = result.blocks[0].kind else { Issue.record("Lost the table"); return }
    expectNoDifference(table.rows.map(\.id), [0, 1])
    #expect(table.alignments[0] == .leading && table.alignments[1] == .trailing)
  }

  @Test func literalTranslatedPunctuationDoesNotBecomeMarkdown() throws {
    let document = try MarkdownDocument(source: "Hello")
    let text = AttributedString("**ordinary text** [not a link]")
    let result = try document.replacingTextSegments(with: [text])
    expectNoDifference(result.textSegments, [text])
    #expect(result.textSegments[0].runs.allSatisfy { $0.inlinePresentationIntent == nil && $0.link == nil })
  }

  @Test func excerptDoesNotRemoveContentFromFullDocument() throws {
    let source = String(repeating: "Long original text. ", count: 80) + "\n\n![cat](https://example.com/cat.png)"
    let document = try MarkdownDocument(source: source)
    let excerpt = MarkdownExcerpt(document: document)
    #expect(excerpt.isTruncated)
    #expect(document.textSegments[0].characters.count > excerpt.document.textSegments[0].characters.count)
    expectNoDifference(document.blocks.count, 2)
  }

  @Test(arguments: [0, 2])
  func rejectsPartialOrExtraText(count: Int) throws {
    let document = try MarkdownDocument(source: "Hello")
    #expect(throws: (any Error).self) {
      try document.replacingTextSegments(with: Array(repeating: AttributedString("Привет"), count: count))
    }
  }
}
