import CommunityMarkdownFeature
import Foundation
import PhotosUI
import SwiftUI

public struct CommunityEditorView: View {
  @Bindable private var viewModel: CommunityEditorViewModel
  private let autofocus: Bool
  @State private var mode: Mode
  @Environment(\.openURL) private var openURL
  @State private var pickedPhotos: [PhotosPickerItem] = []
  private enum Mode {
    case editor, source
  }

  public init(viewModel: CommunityEditorViewModel, autofocus: Bool = true) {
    self.viewModel = viewModel
    self.autofocus = autofocus
    _mode = State(initialValue: viewModel.sourceOnly ? .source : .editor)
  }

  public var body: some View {
    contentView()
  }
}

private extension CommunityEditorView {
  private func contentView() -> some View {
    editorLifecycleView()
      .task(id: pickedPhotos) {
        guard !pickedPhotos.isEmpty else { return }
        let items = pickedPhotos
        await viewModel.importPhotos(items)
        pickedPhotos = []
      }
      .alert(.editorPhotoImportError, isPresented: photoErrorPresented) {
        Button(.commonOk, role: .cancel, action: viewModel.dismissPhotoError)
      }
      .alert(.editorLink, isPresented: linkEditorPresented, presenting: viewModel.linkEdit) { draft in
        linkEditorActions(draft)
      } message: { draft in
        if draft.title.isEmpty { Text(.editorLinkHint) } else { Text(verbatim: draft.title) }
      }
  }

  private func editorLifecycleView() -> some View {
    editorLayout()
      .safeAreaBar(edge: .bottom) {
        if mode == .editor && !viewModel.sourceOnly { formattingBar() }
      }
      .toolbar { toolbarContent() }
      .onChange(of: mode) { viewModel.prepareForModeChange() }
  }

  private func editorLayout() -> some View {
    VStack(spacing: Constants.contentSpacing) {
      modePickerView()
        .pickerStyle(.segmented)
        .padding(.horizontal)
      editorModeView()
      characterCountView()
    }
  }

  @ViewBuilder
  private func characterCountView() -> some View {
    if viewModel.utf16Count >= Constants.counterThreshold {
      Text(.editorCharacterCount(viewModel.utf16Count, viewModel.characterLimit))
        .font(.caption.monospacedDigit())
        .foregroundStyle(
          viewModel.utf16Count > viewModel.characterLimit ? Constants.error : Constants.secondary)
    }
  }

  private var photoErrorPresented: Binding<Bool> {
    Binding(get: { viewModel.photoError != nil }, set: { if !$0 { viewModel.dismissPhotoError() } })
  }

  private var linkEditorPresented: Binding<Bool> {
    Binding(get: { viewModel.linkEdit != nil }, set: { if !$0 { viewModel.cancelLinkEditing() } })
  }

  @ViewBuilder
  private func linkEditorActions(_ draft: CommunityEditorViewModel.LinkEdit) -> some View {
    TextField(.editorLinkPlaceholder, text: $viewModel.linkAddress)
      .keyboardType(.URL)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    Button(.editorApply) { viewModel.saveLink(draft) }
      .disabled(!viewModel.canSaveLink)
    if let url = draft.originalURL {
      Button(.editorOpenLink) { openURL(url) }
      Button(.editorRemoveLink, role: .destructive) { viewModel.removeLink(draft) }
    }
    Button(.commonCancel, role: .cancel, action: viewModel.cancelLinkEditing)
  }

  private func formattingBar() -> some View {
    formattingButtonsView()
      .buttonStyle(.plain)
      .foregroundStyle(Constants.primary)
      .symbolRenderingMode(.monochrome)
      .padding(Constants.barPadding)
      .glassEffect(in: .capsule)
      .padding(.horizontal, Constants.barInset)
      .padding(.vertical, Constants.barInset)
  }

  private func modePickerView() -> some View {
    Picker(
      .editorModeTitle,
      selection: $mode
    ) {
      Text(
        viewModel.sourceOnly
          ? .editorModePreview
          : .editorModeEditor
      ).tag(Mode.editor)
      Text(.editorModeMarkdown).tag(Mode.source)
    }
  }

  @ViewBuilder
  private func editorModeView() -> some View {
    switch mode {
    case .editor:
      if viewModel.sourceOnly {
        previewView()
      } else {
        PhotoTextView(model: viewModel, autofocus: autofocus)
      }
    case .source:
      TextEditor(text: Binding(get: { viewModel.markdown }, set: { viewModel.loadSource($0) }))
        .font(.body.monospaced())
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, Constants.contentSpacing)
        .accessibilityIdentifier("community.markdownEditor")
    }
  }

  private func previewView() -> some View {
    ScrollView {
      MarkdownPreview(source: viewModel.markdown)
        .padding(.horizontal, Constants.previewHorizontalInset)
        .padding(.vertical, Constants.previewVerticalInset)
    }
  }

  private func formattingButtonsView() -> some View {
    HStack(spacing: Constants.zero) {
      ForEach(CommunityEditorViewModel.Format.allCases) { format in
        formatButton(format)
      }
      linkButton()
        .background(
          viewModel.isLinkSelected ? Constants.selectedBackground : .clear,
          in: .capsule
        )
        .accessibilityLabel(
          .editorAddLink)
      photoButton()
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    if mode == .editor && !viewModel.sourceOnly {
      ToolbarItem(placement: .topBarTrailing) {
        historyButtonsView()
      }
    }
  }

  private func historyButtonsView() -> some View {
    HStack(spacing: Constants.zero) {
      undoButton()
        .accessibilityLabel(.editorUndo)
        .accessibilityIdentifier("community.editorUndo")
        .disabled(!viewModel.canUndo)
      Divider()
        .frame(height: Constants.historyDividerHeight)
        .accessibilityHidden(true)
      redoButton()
        .accessibilityLabel(.editorRedo)
        .accessibilityIdentifier("community.editorRedo")
        .disabled(!viewModel.canRedo)
    }
    .buttonStyle(.plain)
  }

  private func photoButton() -> some View {
    let isImporting = viewModel.isImporting
    return PhotosPicker(selection: $pickedPhotos, maxSelectionCount: Constants.maximumSelectedPhotos, matching: .images) {
      Image(systemName: Constants.photo)
        .opacity(isImporting ? Constants.zero : 1)
        .overlay { if isImporting { ProgressView() } }
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
    .disabled(!viewModel.canInsertPhoto)
    .accessibilityLabel(.editorAddPhoto)
    .accessibilityIdentifier("community.addPhoto")
    .contextMenu { photoActions() }
  }

  @ViewBuilder
  private func photoActions() -> some View {
    if viewModel.selectedPhotoID != nil {
      Button(.editorPhotoMoveStart) { viewModel.movePhoto(to: .start) }
      Button(.editorPhotoMoveDown) { viewModel.movePhoto(to: .afterParagraph) }
      Button(.editorPhotoMoveEnd) { viewModel.movePhoto(to: .end) }
      Button(.editorPhotoRemove, role: .destructive, action: viewModel.removePhoto)
    }
  }

  private func symbol(for format: CommunityEditorViewModel.Format) -> String {
    switch format {
    case .bold: Constants.bold
    case .italic: Constants.italic
    case .strike: Constants.strike
    case .code: Constants.code
    }
  }

  private func title(for format: CommunityEditorViewModel.Format) -> LocalizedStringResource {
    switch format {
    case .bold: .editorBold
    case .italic: .editorItalic
    case .strike: .editorStrike
    case .code: .editorCode
    }
  }

  private func stateTitle(_ state: CommunityEditorViewModel.FormatState) -> LocalizedStringResource {
    switch state {
    case .on: .editorOn
    case .off: .editorOff
    case .mixed: .editorMixed
    }
  }

  private func linkButton() -> some View {
    Button {
      viewModel.editLink()
    } label: {
      Image(systemName: Constants.link)
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  private func undoButton() -> some View {
    Button {
      viewModel.undo()
    } label: {
      Image(systemName: Constants.undo)
        .frame(width: Constants.touchTarget, height: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  private func redoButton() -> some View {
    Button {
      viewModel.redo()
    } label: {
      Image(systemName: Constants.redo)
        .frame(width: Constants.touchTarget, height: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  private func formatButton(_ format: CommunityEditorViewModel.Format) -> some View {
    let state = viewModel.state(for: format)
    return Button {
      viewModel.toggle(format)
    } label: {
      Image(systemName: symbol(for: format))
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background(state == .on ? Constants.selectedBackground : .clear, in: .capsule)
    .accessibilityLabel(title(for: format))
    .accessibilityValue(stateTitle(state))
  }
}

private enum Constants {
  static let maximumSelectedPhotos = 10
  static let photo = "photo.badge.plus"
  static let bold = "bold"
  static let italic = "italic"
  static let strike = "strikethrough"
  static let code = "chevron.left.forwardslash.chevron.right"
  static let zero: CGFloat = 0
  static let contentSpacing: CGFloat = 12
  static let touchTarget: CGFloat = 44
  static let historyDividerHeight: CGFloat = 20
  static let barPadding: CGFloat = 6
  static let barInset: CGFloat = 8
  static let previewHorizontalInset: CGFloat = 17
  static let previewVerticalInset: CGFloat = 8
  static let selectedBackground = Color.primary.opacity(0.12)
  static let primary = Color.primary
  static let secondary = Color.secondary
  static let error = Color.red
  static let counterThreshold = 4000
  static let link = "link"
  static let undo = "arrow.uturn.backward"
  static let redo = "arrow.uturn.forward"
}
