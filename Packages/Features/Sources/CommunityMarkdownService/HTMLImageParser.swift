import Foundation

struct HTMLImageParser {
  static func parse(_ source: String) -> MarkdownDocument.Inline.Kind? {
    let tag = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard matches("^<img\\b[^>]*?/?>$", in: tag),
          let value = attribute("src", in: tag), let url = URL(string: value),
          MarkdownCodec.isAllowedLink(url) else { return nil }
    return .image(url: url, alt: attribute("alt", in: tag) ?? "",
                       width: dimension("width", in: tag), height: dimension("height", in: tag))
  }
}

private extension HTMLImageParser {
  static func dimension(_ name: String, in tag: String) -> Double? {
    guard let value = attribute(name, in: tag) else { return nil }
    let number = value.lowercased().replacingOccurrences(of: "px", with: "")
    guard let result = Double(number), result.isFinite, result > 0 else { return nil }
    return result
  }

  static func matches(_ pattern: String, in source: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
    return expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) != nil
  }

  static func attribute(_ name: String, in tag: String) -> String? {
    let pattern = "(?:^|\\s)" + name + "\\s*=\\s*([\"'])(.*?)\\1"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
          let range = Range(match.range(at: 2), in: tag) else { return nil }
    return String(tag[range])
  }
}
