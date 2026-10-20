import SwiftUI
import UIKit

struct PhotoTextView: UIViewRepresentable {
  let model: CommunityEditorViewModel
  let autofocus: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  func makeUIView(context: Context) -> PhotoTextArea {
    let view = PhotoTextArea(usingTextLayoutManager: true)
    context.coordinator.dynamicTypeSize = dynamicTypeSize
    view.autofocus = autofocus
    view.font = .preferredFont(forTextStyle: .body)
    view.backgroundColor = .systemBackground
    view.adjustsFontForContentSizeCategory = true
    view.textContainerInset = Constants.editorInsets
    view.delegate = context.coordinator
    view.allowsEditingTextAttributes = true
    view.accessibilityIdentifier = "community.richEditor"
    view.accessibilityLabel = String(localized: .editorAccessibilityLabel)
    model.attach(view)
    return view
  }

  func updateUIView(_ uiView: PhotoTextArea, context: Context) {
    guard context.coordinator.dynamicTypeSize != dynamicTypeSize else { return }
    context.coordinator.dynamicTypeSize = dynamicTypeSize
    model.updateFonts()
  }

  func makeCoordinator() -> Coordinator { Coordinator(model) }

  static func dismantleUIView(_ uiView: PhotoTextArea, coordinator: Coordinator) {
    uiView.delegate = nil
    uiView.pasteDelegate = nil
    coordinator.model.detach()
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    let model: CommunityEditorViewModel
    var dynamicTypeSize: DynamicTypeSize?

    init(_ model: CommunityEditorViewModel) { self.model = model }

    func textViewDidChange(_ textView: UITextView) { model.refresh() }

    func textViewDidChangeSelection(_ textView: UITextView) { model.selectionChanged() }

    func textView(
      _ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction
    ) -> UIAction? {
      guard case let .link(url) = textItem.content else { return defaultAction }
      let range = textItem.range
      return UIAction(title: String(localized: .editorLink)) { [weak model] _ in
        model?.beginLinkEditing(in: range, url: url)
      }
    }
  }
}

final class PhotoTextArea: UITextView {
  var autofocus = false
  private var didAutofocus = false
  private var needsSelectionReveal = false
  weak var model: CommunityEditorViewModel?
  lazy var photoClipboard = PhotoClipboard()
  var systemUndoManager: UndoManager? { super.undoManager }
  override var undoManager: UndoManager? { super.undoManager ?? model?.history }
  override var frame: CGRect {
    willSet {
      if newValue.size != frame.size { revealVisibleSelection() }
    }
  }
  override var bounds: CGRect {
    willSet {
      if newValue.size != bounds.size { revealVisibleSelection() }
    }
  }

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    configurePaste()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configurePaste()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { revealSelection() }
  }

  func revealSelection() {
    needsSelectionReveal = true
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard needsSelectionReveal,
      window != nil, bounds.width > 0, bounds.height > 0,
      let range = selectedTextRange else { return }
    needsSelectionReveal = false
    if let layout = textLayoutManager { layout.ensureLayout(for: layout.documentRange) }
    revealCaret(caretRect(for: range.end))
    if autofocus, !didAutofocus {
      didAutofocus = true
      becomeFirstResponder()
    }
  }

  override func copy(_ sender: Any?) {
    let text = photoClipboard.captureSelection()
    super.copy(sender)
    photoClipboard.remember(text)
  }

  override func cut(_ sender: Any?) {
    let text = photoClipboard.captureSelection()
    super.cut(sender)
    photoClipboard.remember(text)
  }
}

private extension PhotoTextArea {
  private func revealVisibleSelection() {
    guard !needsSelectionReveal, isFirstResponder, let range = selectedTextRange else { return }
    let visible = bounds.inset(by: adjustedContentInset)
    if visible.intersects(caretRect(for: range.end)) { needsSelectionReveal = true }
  }

  private func revealCaret(_ caret: CGRect) {
    let visible = bounds.inset(by: adjustedContentInset).inset(by: textContainerInset)
    var offset = contentOffset
    if caret.minY < visible.minY {
      offset.y += caret.minY - visible.minY
    } else if caret.maxY > visible.maxY {
      offset.y += caret.maxY - visible.maxY
    }
    setContentOffset(offset, animated: false)
  }

  private func configurePaste() {
    smartInsertDeleteType = .no
    let configuration = UIPasteConfiguration(forAccepting: NSAttributedString.self)
    configuration.addTypeIdentifiers(forAccepting: UIImage.self)
    configuration.addAcceptableTypeIdentifiers([PhotoFragment.typeIdentifier])
    pasteConfiguration = configuration
  }
}

private enum Constants {
  static let editorInsets = UIEdgeInsets(top: 12, left: 18, bottom: 24, right: 18)
}
