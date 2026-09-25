import Foundation
import SwiftUI

enum EditorTextFormatting {
  static func intent(in attributes: AttributeContainer) -> InlinePresentationIntent {
    let font = (attributes.font ?? .body).resolve(in: EnvironmentValues().fontResolutionContext)
    var intent: InlinePresentationIntent = []
    if font.isBold { intent.insert(.stronglyEmphasized) }
    if font.isItalic { intent.insert(.emphasized) }
    if font.isMonospaced { intent.insert(.code) }
    if attributes.strikethroughStyle != nil { intent.insert(.strikethrough) }
    return intent
  }

  static func apply(_ intent: InlinePresentationIntent, to attributes: inout AttributeContainer) {
    attributes.inlinePresentationIntent = nil
    attributes.font = Font.body
      .monospaced(intent.contains(.code))
      .bold(intent.contains(.stronglyEmphasized))
      .italic(intent.contains(.emphasized))
    attributes.strikethroughStyle = intent.contains(.strikethrough) ? .single : nil
  }

  static func editable(_ text: AttributedString) -> AttributedString {
    var result = text
    for run in text.runs {
      var attributes = run.attributes
      apply(attributes.inlinePresentationIntent ?? [], to: &attributes)
      result[run.range].setAttributes(attributes)
    }
    return result
  }

  static func serializable(_ text: AttributedString) -> AttributedString {
    var result = text
    for run in text.runs {
      var attributes = AttributeContainer()
      attributes.inlinePresentationIntent = intent(in: run.attributes)
      attributes.link = run.link
      result[run.range].setAttributes(attributes)
    }
    return result
  }
}
