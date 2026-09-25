import Foundation

public enum MarkdownLiteral {
  public static func encode(_ text: String) -> String {
    text.map { character in
      if character == "&" { return "&amp;" }
      if Constants.escaped.contains(character) { return "\\\(character)" }
      return String(character)
    }.joined()
  }
}

private enum Constants {
  static let escaped = Set("\\`*_{}[]<>()#+-.!|~>")
}
