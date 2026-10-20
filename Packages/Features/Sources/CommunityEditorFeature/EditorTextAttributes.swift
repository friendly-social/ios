import Foundation
import UIKit

public enum EditorTextFormat: Int, CaseIterable, Identifiable {
  case bold = 1
  case italic = 2
  case strike = 4
  case code = 8
  public var id: Self { self }
}

@MainActor
enum EditorTextAttributes {
  static func make(formatBits: Int) -> [NSAttributedString.Key: Any] {
    let strike = formatBits & EditorTextFormat.strike.rawValue != 0
      ? NSUnderlineStyle.single.rawValue : 0
    return [.font: font(for: formatBits), .foregroundColor: UIColor.label,
      .strikethroughStyle: strike]
  }

  static func formatBits(in attributes: [NSAttributedString.Key: Any]) -> Int {
    var bits = 0
    if let font = attributes[.font] as? UIFont {
      let traits = font.fontDescriptor.symbolicTraits
      if traits.contains(.traitBold) { bits |= EditorTextFormat.bold.rawValue }
      if traits.contains(.traitItalic) { bits |= EditorTextFormat.italic.rawValue }
      if traits.contains(.traitMonoSpace) { bits |= EditorTextFormat.code.rawValue }
    }
    if let strike = attributes[.strikethroughStyle] as? Int, strike != 0 {
      bits |= EditorTextFormat.strike.rawValue
    }
    return bits
  }
}

private extension EditorTextAttributes {
  private static func font(for bits: Int) -> UIFont {
    let size = UIFont.preferredFont(forTextStyle: .body).pointSize
    let weight: UIFont.Weight = bits & EditorTextFormat.bold.rawValue != 0 ? .bold : .regular
    let base: UIFont = bits & EditorTextFormat.code.rawValue != 0
      ? .monospacedSystemFont(ofSize: size, weight: weight)
      : .preferredFont(forTextStyle: .body)
    var traits = base.fontDescriptor.symbolicTraits
    if bits & EditorTextFormat.bold.rawValue != 0 { traits.insert(.traitBold) }
    if bits & EditorTextFormat.italic.rawValue != 0 { traits.insert(.traitItalic) }
    return UIFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor,
      size: size)
  }
}
