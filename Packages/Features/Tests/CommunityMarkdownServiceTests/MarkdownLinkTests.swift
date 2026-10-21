import CommunityMarkdownService
import Foundation
import Testing

struct MarkdownLinkTests {
  @Test(arguments: Constants.urls)
  func richTextPublishesExactLinkDestination(address: String) throws {
    let source = MarkdownCodec().encode(AttributedString("До 👋 " + address + " после"))
    #expect(try links(source) == [URL(string: address)!])
    #expect(String(try MarkdownCodec().decode(source).characters) == "До 👋 " + address + " после")
  }

  @Test(arguments: Constants.urls)
  func plainReplyPublishesExactLinkDestination(address: String) throws {
    #expect(try links(MarkdownLiteral.encode(address)) == [URL(string: address)!])
  }

  @Test func existingPlainURLsAreClickableInPostRendering() throws {
    let source = Constants.urls.prefix(3).joined(separator: "\n\n")
    #expect(try links(source) == Constants.urls.prefix(3).compactMap(URL.init(string:)))
  }

  @Test func surroundingPunctuationIsNotPartOfURL() throws {
    let source = "Привет 👨‍👩‍👧‍👦 (https://example.com/path)."
    #expect(try links(source) == [URL(string: "https://example.com/path")!])
    #expect(String(try MarkdownCodec().decode(source).characters) == source)
  }

  @Test func formattingInsideURLIsPreserved() throws {
    var text = AttributedString("https://example.com")
    let end = text.characters.index(text.startIndex, offsetBy: 8)
    text[text.startIndex..<end].inlinePresentationIntent = .stronglyEmphasized
    let decoded = try MarkdownCodec().decode(MarkdownCodec().encode(text))
    #expect(String(decoded.characters) == String(text.characters))
    #expect(decoded.runs.allSatisfy { $0.link == URL(string: "https://example.com") })
    #expect(decoded.runs.first?.inlinePresentationIntent == .stronglyEmphasized)
  }

  @Test func codeBlocksRemainLiteral() throws {
    let document = try MarkdownDocument(source: "```\nhttps://example.com\n```")
    guard case let .code(_, text) = document.blocks.first?.kind else {
      Issue.record("Expected a code block")
      return
    }
    #expect(text == "https://example.com\n")
    #expect(try links("`https://example.com`").isEmpty)
  }

  @Test func explicitLinkKeepsItsDestinationEvenWhenLabelLooksLikeURL() throws {
    var text = AttributedString("https://label.example.com")
    text.link = URL(string: "https://destination.example.com/?a=1&copy;=literal")
    let decoded = try MarkdownCodec().decode(MarkdownCodec().encode(text))
    #expect(decoded.runs.compactMap(\.link) == [text.link!])
  }

  @Test func inlineCodeDoesNotBecomeLink() throws {
    var text = AttributedString(Constants.urls[0])
    text.inlinePresentationIntent = .code
    #expect(try links(MarkdownCodec().encode(text)).isEmpty)
  }
}

private extension MarkdownLinkTests {
  private func links(_ source: String) throws -> [URL] {
    try MarkdownDocument(source: source).blocks.flatMap { block -> [URL] in
      guard case let .paragraph(inlines) = block.kind else { return [] }
      return inlines.flatMap { inline -> [URL] in
        guard case let .text(text) = inline.kind else { return [] }
        return text.runs.compactMap(\.link)
      }
    }
  }
}

private enum Constants {
  static let urls = [
    "https://www.instagram.com/reel/DeCVXG3oz-Q/?obrf=MW9iYzB0aDNnZ3A5MQ==",
    "https://www.instagram.com/reel/DemlJ9ctHGE/?xtok=MWl5bXVlNTk2Zmoycg==",
    "https://www.instagram.com/reel/Dera9yloYEM/?xtok=MXRkNHBvNGFzaWZheA==",
    "https://example.com/a_b?first=1&copy;=literal#section",
    "https://example.com/path(one)/file?q=a*b&next=two",
  ]
}
