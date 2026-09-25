import CommunityMarkdownService
import Foundation
import Testing

struct MarkdownExcerptTests {
  @Test func shortPostWithImageIsNotNeedlesslyTruncated() throws {
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: "**Hello**\n\n![Photo](https://example.com/one.jpg)"))
    #expect(!excerpt.isTruncated)
    #expect(excerpt.document.blocks.count == 2)
  }

  @Test func hiddenImagesAreAbsentFromRenderTree() throws {
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: "![One](https://example.com/one.jpg)\n\n![Two](https://example.com/two.jpg)"))
    #expect(excerpt.isTruncated)
    let images = excerpt.document.blocks.flatMap { block -> [MarkdownDocument.Inline] in
      guard case let .paragraph(content) = block.kind else { return [] }
      return content.filter { if case .image = $0.kind { true } else { false } }
    }
    #expect(images.count == 1)
  }

  @Test func longFormattedTextRetainsAttributesAndUnicode() throws {
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: "**" + String(repeating: "👨‍👩‍👧‍👦", count: 600) + "**"))
    #expect(excerpt.isTruncated)
    guard case let .paragraph(content) = try #require(excerpt.document.blocks.first).kind,
      case let .text(text) = try #require(content.first).kind else {
      Issue.record("Expected text paragraph"); return
    }
    #expect(text.characters.count == 401)
    #expect(text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
  }

  @Test func smallRemainderDoesNotCreateReadMoreButton() throws {
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: String(repeating: "a", count: 450)))
    #expect(!excerpt.isTruncated)
  }

  @Test func longListHasBoundedRenderTree() throws {
    let source = (1...100).map { "- Item \($0)" }.joined(separator: "\n")
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: source))
    #expect(excerpt.isTruncated)
    guard case let .list(items) = try #require(excerpt.document.blocks.first).kind else {
      Issue.record("Expected list"); return
    }
    #expect(items.count == 4)
  }

  @Test func tablePreviewDoesNotBuildAllRows() throws {
    let source = "| A | B |\n|---|---|\n" + (1...20).map { "| \($0) | Value |" }.joined(separator: "\n")
    let excerpt = MarkdownExcerpt(document: try MarkdownDocument(source: source))
    #expect(excerpt.isTruncated)
    guard case let .table(table) = try #require(excerpt.document.blocks.first).kind else {
      Issue.record("Expected table"); return
    }
    #expect(table.rows.count == 3)
  }
}
