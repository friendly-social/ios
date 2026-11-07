import Foundation

final class SVGDimensions: NSObject, XMLParserDelegate {
  private var size: CGSize?

  static func read(_ data: Data) -> CGSize? {
    let delegate = SVGDimensions()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    parser.shouldResolveExternalEntities = false
    _ = parser.parse()
    return delegate.size
  }

  func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName qName: String?, attributes: [String: String]
  ) {
    guard size == nil else { return }
    guard elementName.lowercased() == "svg" else { parser.abortParsing(); return }
    let viewBox = attributes["viewBox"]?.split(whereSeparator: { $0.isWhitespace || $0 == "," }).compactMap { Double($0) }
    let width = number(attributes["width"]) ?? (viewBox?.count == 4 ? viewBox?[2] : nil)
    let height = number(attributes["height"]) ?? (viewBox?.count == 4 ? viewBox?[3] : nil)
    if let width, let height, width > 0, height > 0, width.isFinite, height.isFinite {
      size = CGSize(width: width, height: height)
    }
    parser.abortParsing()
  }
}

private extension SVGDimensions {
  func number(_ value: String?) -> Double? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.hasSuffix("px") { return Double(normalized.dropLast(2)) }
    return Double(normalized)
  }
}
