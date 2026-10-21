import Foundation

enum MarkdownLinks {
  static func detecting(in text: AttributedString) -> AttributedString {
    guard let detector else { return text }
    let string = String(text.characters)
    var result = text
    for match in detector.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
      guard let url = match.url, MarkdownCodec.isAllowedLink(url),
            let range = Range(match.range, in: string),
            let lower = AttributedString.Index(range.lowerBound, within: result),
            let upper = AttributedString.Index(range.upperBound, within: result)
      else { continue }
      let target = lower..<upper
      guard result[target].runs.allSatisfy({
        $0.link == nil && !($0.inlinePresentationIntent ?? []).contains(.code)
      }) else { continue }
      result[target].link = url
    }
    return result
  }

  static func destination(_ url: URL) -> String {
    url.absoluteString.map { character in
      if character == "&" { return "&amp;" }
      if "\\()<>".contains(character) { return "\\\(character)" }
      return String(character)
    }.joined()
  }

  private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}
