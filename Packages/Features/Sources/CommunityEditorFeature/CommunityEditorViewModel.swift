import CommunityMarkdownService
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
public final class CommunityEditorViewModel {
  public enum Format: String, CaseIterable, Identifiable {
    case bold, italic, strike, code
    public var id: Self { self }
    var intent: InlinePresentationIntent {
      switch self {
      case .bold: .stronglyEmphasized
      case .italic: .emphasized
      case .strike: .strikethrough
      case .code: .code
      }
    }
    var symbol: String {
      switch self {
      case .bold: Constants.bold
      case .italic: Constants.italic
      case .strike: Constants.strike
      case .code: Constants.code
      }
    }
    var title: LocalizedStringResource {
      switch self {
      case .bold: .editorBold
      case .italic: .editorItalic
      case .strike:
        .editorStrike
      case .code: .editorCode
      }
    }
  }

  public var text: AttributedString
  public var selection = AttributedTextSelection()
  public var source: String
  public private(set) var sourceOnly: Bool
  public var linkAddress = "https://"
  public var showsLinkEditor = false
  public private(set) var isEditingLink = false
  public private(set) var canUndo = false
  public private(set) var canRedo = false
  private let codec: MarkdownCodec
  private var originalText: AttributedString
  private var linkSelection: AttributedTextSelection?

  public init(
    source: String = "", codec: MarkdownCodec = .init()
  ) {
    self.codec = codec
    self.source = source
    let text = EditorTextFormatting.editable((try? codec.decode(source)) ?? AttributedString(source))
    self.text = text
    self.originalText = text
    self.sourceOnly = codec.requiresSourceEditing(source)
  }

  public var markdown: String {
    sourceOnly || text == originalText ? source : codec.encode(EditorTextFormatting.serializable(text))
  }
  public var utf16Count: Int { markdown.utf16.count }
  public var canPublish: Bool {
    !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && utf16Count <= Constants.characterLimit
  }

  public func loadSource(_ value: String) {
    source = value
    text = EditorTextFormatting.editable((try? codec.decode(value)) ?? AttributedString(value))
    originalText = text
    sourceOnly = codec.requiresSourceEditing(value)
    selection = AttributedTextSelection()
  }

  public func refreshUndoAvailability(_ manager: UndoManager?) {
    canUndo = manager?.canUndo ?? false
    canRedo = manager?.canRedo ?? false
  }

  public func clearUndoHistory(_ manager: UndoManager?) {
    manager?.removeAllActions()
    refreshUndoAvailability(manager)
  }

  public func undo(_ manager: UndoManager?) {
    manager?.undo()
    refreshUndoAvailability(manager)
  }

  public func redo(_ manager: UndoManager?) {
    manager?.redo()
    refreshUndoAvailability(manager)
  }

  public func observeUndoChanges(_ manager: UndoManager?) async {
    refreshUndoAvailability(manager)
    async let groupClosed: Void = observeUndoNotification(.NSUndoManagerDidCloseUndoGroup, manager)
    async let undone: Void = observeUndoNotification(.NSUndoManagerDidUndoChange, manager)
    async let redone: Void = observeUndoNotification(.NSUndoManagerDidRedoChange, manager)
    _ = await (groupClosed, undone, redone)
  }

  public enum FormatState {
    case on, off, mixed

    var title: LocalizedStringResource {
      switch self {
      case .on: .editorOn
      case .off: .editorOff
      case .mixed: .editorMixed
      }
    }
  }

  public func state(for format: Format) -> FormatState {
    if case .insertionPoint = selection.indices(in: text) {
      let intent = EditorTextFormatting.intent(in: selection.typingAttributes(in: text))
      return intent.contains(format.intent) ? .on : .off
    }
    let values = selection.attributes(in: text).map {
      EditorTextFormatting.intent(in: $0).contains(format.intent)
    }
    if values.allSatisfy({ $0 }) && !values.isEmpty { return .on }
    return values.contains(true) ? .mixed : .off
  }

  public func toggle(_ format: Format, undoManager: UndoManager? = nil) {
    registerUndo(with: undoManager)
    let enable = state(for: format) != .on
    text.transformAttributes(in: &selection) { attributes in
      var intent = EditorTextFormatting.intent(in: attributes)
      if enable { intent.insert(format.intent) } else { intent.remove(format.intent) }
      EditorTextFormatting.apply(intent, to: &attributes)
    }
  }

  public var validLink: URL? {
    guard let url = URL(string: linkAddress), MarkdownCodec.isAllowedLink(url) else { return nil }
    return url
  }

  public var isLinkSelected: Bool { selectedLink != nil }

  private var selectedLink: (url: URL, range: Range<AttributedString.Index>)? {
    let links = text.runs[\.link].compactMap { value, range in
      value.map { (url: $0, range: range) }
    }
    return links.first { link in
      switch selection.indices(in: text) {
      case let .insertionPoint(index):
        return link.range.lowerBound <= index && index <= link.range.upperBound
      case let .ranges(ranges): return ranges.ranges.contains { $0.overlaps(link.range) }
      }
    }
  }

  public func editLink() {
    let link = selectedLink
    if let link {
      selection = AttributedTextSelection(range: link.range)
    }
    isEditingLink = link != nil
    linkSelection = selection
    linkAddress = link?.url.absoluteString ?? "https://"
    showsLinkEditor = true
  }

  public func removeLink(undoManager: UndoManager? = nil) {
    guard isEditingLink else { return }
    if let linkSelection { selection = linkSelection }
    registerUndo(with: undoManager)
    text.transformAttributes(in: &selection) { $0.link = nil }
    showsLinkEditor = false
  }

  public func applyLink(undoManager: UndoManager? = nil) {
    guard let url = validLink else { return }
    if let linkSelection { selection = linkSelection }
    registerUndo(with: undoManager)
    text.transformAttributes(in: &selection) { $0.link = url }
    if case let .ranges(ranges) = selection.indices(in: text),
       let end = ranges.ranges.last?.upperBound {
      selection = AttributedTextSelection(insertionPoint: end)
      text.transformAttributes(in: &selection) { $0.link = nil }
    }
    showsLinkEditor = false
  }

  public func stopLinkAtBoundary() {
    guard case let .insertionPoint(index) = selection.indices(in: text),
          let link = text.runs[\.link].first(where: { $0.0 != nil && $0.1.upperBound == index }),
          link.1.lowerBound != index else { return }
    guard selection.typingAttributes(in: text).link != nil else { return }
    text.transformAttributes(in: &selection) { $0.link = nil }
  }


}

private extension CommunityEditorViewModel {
  private func observeUndoNotification(_ name: Notification.Name, _ manager: UndoManager?) async {
    for await _ in NotificationCenter.default.notifications(named: name, object: manager) {
      guard !Task.isCancelled else { return }
      refreshUndoAvailability(manager)
    }
  }

  private func registerUndo(with manager: UndoManager?) {
    guard let manager else { return }
    let previousText = text
    let previousSelection = selection
    manager.registerUndo(withTarget: manager) { [weak self, weak manager] _ in
      MainActor.assumeIsolated {
        guard let target = self, let manager else { return }
        target.registerUndo(with: manager)
        target.text = previousText
        target.selection = previousSelection
      }
    }
    manager.setActionName(
      String(localized: .editorFormatting))
  }
}

private enum Constants {
  static let characterLimit = 4096
  static let bold = "bold"
  static let italic = "italic"
  static let strike = "strikethrough"
  static let code = "chevron.left.forwardslash.chevron.right"
}
