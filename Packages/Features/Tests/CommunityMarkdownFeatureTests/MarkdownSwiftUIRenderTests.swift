import CommunityMarkdownFeature
import Foundation
import SwiftUI
import Testing
import UIKit

@MainActor struct MarkdownSwiftUIRenderTests {
  @Test(arguments: MarkdownInlineSample.allCases, MarkdownRenderAppearance.allCases)
  func matchesNativeText(sample: MarkdownInlineSample, appearance: MarkdownRenderAppearance) throws {
    let actual = try render(MarkdownPreview(source: sample.source), appearance: appearance)
    let expected = try render(sample.expected, appearance: appearance)
    if actual.pngData() != expected.pngData() {
      Attachment.record(actual, named: "\(sample.rawValue)-actual.png")
      Attachment.record(expected, named: "\(sample.rawValue)-expected.png")
    }
    #expect(actual.size == expected.size)
    #expect(actual.pngData() == expected.pngData())
  }

  @Test(arguments: MarkdownParserLimitation.allCases, MarkdownRenderAppearance.allCases)
  func knownParserLimitations(sample: MarkdownParserLimitation, appearance: MarkdownRenderAppearance) throws {
    let actual = try render(MarkdownPreview(source: sample.source), appearance: appearance)
    let expected = try render(Text(verbatim: sample.source), appearance: appearance)
    withKnownIssue("swift-cmark 0.9: \(sample.rawValue)") {
      #expect(actual.pngData() == expected.pngData())
    }
  }
}

private extension MarkdownSwiftUIRenderTests {
  private func render(_ view: some View, appearance: MarkdownRenderAppearance) throws -> UIImage {
    let renderer = ImageRenderer(content: view
      .font(.body)
      .frame(width: Constants.width, alignment: .topLeading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.vertical, Constants.padding)
      .background(appearance == .dark ? Color.black : Color.white)
      .environment(\.colorScheme, appearance == .dark ? .dark : .light)
      .environment(\.dynamicTypeSize, appearance == .accessibility ? .accessibility3 : .large)
      .environment(\.locale, Locale(identifier: "en_US")))
    renderer.scale = Constants.scale
    return try #require(renderer.uiImage)
  }
}

enum MarkdownRenderAppearance: String, CaseIterable, Sendable {
  case light, dark, accessibility
}

enum MarkdownInlineSample: String, CaseIterable, Sendable {
  case plain, bold, italic, nested, strike, hardBreak, softBreak, entities
  case code, paddedCode, spacesOnlyCode, escapedSyntax, entityLineBreaks, link
  case complexNested, deepNested, heading

  var source: String {
    switch self {
    case .plain: "Hello world"
    case .bold: "Hello **world**"
    case .italic: "Hello *world*"
    case .nested: "**bold *both* bold**"
    case .strike: "Hello ~~world~~"
    case .hardBreak: "foo\\\nbar"
    case .softBreak: "foo\nbar"
    case .entities: "&copy; &nbsp; &amp;"
    case .code: "`a*b`"
    case .paddedCode: "` a`"
    case .spacesOnlyCode: "`  `"
    case .escapedSyntax: ##"\# heading \*\*literal\*\* \[name\]"##
    case .entityLineBreaks: "foo&#10;&#10;bar"
    case .complexNested: "**Gomphocarpus (*Gomphocarpus physocarpus*, syn.\n*Asclepias physocarpa*)**"
    case .deepNested: "*foo **bar *baz* bim** bop*"
    case .heading: "# Heading"
    case .link: "[Site](https://example.com/path?q=one&next=two)"
    }
  }

  @MainActor var expected: Text {
    switch self {
    case .plain: Text("Hello world")
    case .bold: Text("Hello \(Text("world").bold())")
    case .italic: Text("Hello \(Text("world").italic())")
    case .nested: Text("bold \(Text("both").italic()) bold").bold()
    case .strike: Text("Hello \(Text("world").strikethrough())")
    case .hardBreak, .softBreak: Text("foo\nbar")
    case .entities: Text("© \u{a0} &")
    case .code: Text("a*b").monospaced()
    case .paddedCode: Text(" a").monospaced()
    case .spacesOnlyCode: Text("  ").monospaced()
    case .escapedSyntax: Text(verbatim: "# heading **literal** [name]")
    case .entityLineBreaks: Text("foo\n\nbar")
    case .complexNested: Text("Gomphocarpus (\(Text("Gomphocarpus physocarpus").italic()), syn.\n\(Text("Asclepias physocarpa").italic()))").bold()
    case .deepNested: Text("foo \(Text("bar baz bim").bold()) bop").italic()
    case .heading: Text("Heading").font(.title.bold())
    case .link: Text(linkLabel())
    }
  }
}

private extension MarkdownInlineSample {
  @MainActor private func linkLabel() -> AttributedString {
    var value = AttributedString("Site")
    value.link = URL(string: "https://example.com/path?q=one&next=two")
    return value
  }
}

enum MarkdownParserLimitation: String, CaseIterable, Sendable {
  case currencyPunctuation, invalidNumericEntity

  var source: String {
    switch self {
    case .currencyPunctuation: "*£*bravo."
    case .invalidNumericEntity: "&#87654321;"
    }
  }
}

private enum Constants {
  static let width: CGFloat = 320
  static let padding: CGFloat = 1
  static let scale: CGFloat = 2
}
