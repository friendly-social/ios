import CommunityMarkdownFeature
import Foundation
import SwiftUI

public struct CommunityEditorView: View {
  @Bindable private var viewModel: CommunityEditorViewModel
  private let showsSamples: Bool
  @State private var mode: Mode
  @FocusState private var focused: Bool
  @Environment(\.undoManager) private var undoManager
  private enum Mode {
    case editor, source
  }

  public init(viewModel: CommunityEditorViewModel, showsSamples: Bool = false) {
    self.viewModel = viewModel
    self.showsSamples = showsSamples
    _mode = State(initialValue: showsSamples ? .editor : viewModel.sourceOnly ? .source : .editor)
  }

  public var body: some View {
    contentView()
  }
}

private extension CommunityEditorView {

  private func contentView() -> some View {
    editorLayout()
      .safeAreaBar(edge: .bottom) {
        if mode == .editor && !viewModel.sourceOnly { formattingBar() }
      }
      .toolbar { toolbarContent() }
      .onAppear { if !showsSamples { focused = true } }
      .onChange(of: mode) { old, new in changeMode(from: old, to: new) }
      .onChange(of: viewModel.source) {
        if mode == .source { viewModel.loadSource(viewModel.source) }
      }
      .task(id: undoManager) {
        viewModel.clearUndoHistory(undoManager)
        await viewModel.observeUndoChanges(undoManager)
      }
      .onDisappear { viewModel.clearUndoHistory(undoManager) }
      .onChange(of: viewModel.text) { viewModel.refreshUndoAvailability(undoManager) }
      .onChange(of: viewModel.selection) {
        viewModel.stopLinkAtBoundary()
      }
      .alert(.editorLink, isPresented: $viewModel.showsLinkEditor) {
        linkEditorActions()
      } message: {
        Text(.editorLinkHint)
      }
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
    if showsSamples || viewModel.utf16Count >= Constants.counterThreshold {
      Text(.editorCharacterCount(viewModel.utf16Count, Constants.characterLimit))
        .font(.caption.monospacedDigit())
        .foregroundStyle(
          viewModel.utf16Count > Constants.characterLimit ? Constants.error : Constants.secondary)
    }
  }

  private func changeMode(from old: Mode, to new: Mode) {
    focused = false
    if old == .source || new == .source {
      viewModel.clearUndoHistory(undoManager)
    }
    if old == .source {
      viewModel.loadSource(viewModel.source)
    } else if new == .source {
      viewModel.source = viewModel.markdown
    }
  }

  @ViewBuilder
  private func linkEditorActions() -> some View {
    TextField(.editorLinkPlaceholder, text: $viewModel.linkAddress)
      .textInputAutocapitalization(.never)
    Button(.editorApply) {
      viewModel.applyLink(undoManager: undoManager)
      focused = true
    }
    .disabled(viewModel.validLink == nil)
    if viewModel.isEditingLink {
      Button(.editorRemoveLink, role: .destructive) {
        viewModel.removeLink(undoManager: undoManager)
        focused = true
      }
    }
    Button(.commonCancel, role: .cancel) { focused = true }
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

  private func load(_ source: String) {
    viewModel.clearUndoHistory(undoManager)
    viewModel.loadSource(source)
    mode = viewModel.sourceOnly ? .source : .editor
  }


  @ViewBuilder
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
        TextEditor(text: $viewModel.text, selection: $viewModel.selection)
          .focused($focused)
          .padding(.horizontal, Constants.contentSpacing)
          .accessibilityIdentifier("community.richEditor")
      }
    case .source:
      TextEditor(text: $viewModel.source)
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

  @ViewBuilder
  private func formattingButtonsView() -> some View {
    HStack(spacing: Constants.zero) {
      ForEach(CommunityEditorViewModel.Format.allCases) { format in
        formatButton(format)
          .buttonStyle(.plain)
          .background(
            viewModel.state(for: format) == .on ? Constants.selectedBackground : .clear,
            in: .capsule
          )
          .accessibilityLabel(format.title)
          .accessibilityValue(viewModel.state(for: format).title)
      }
      linkButton()
        .background(
          viewModel.isLinkSelected ? Constants.selectedBackground : .clear,
          in: .capsule
        )
        .accessibilityLabel(
          .editorAddLink)
      undoButton()
        .accessibilityLabel(.editorUndo)
        .disabled(!viewModel.canUndo)
        .foregroundStyle(viewModel.canUndo ? Constants.primary : Constants.secondary)
      redoButton()
        .accessibilityLabel(.editorRedo)
        .disabled(!viewModel.canRedo)
        .foregroundStyle(viewModel.canRedo ? Constants.primary : Constants.secondary)
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    if showsSamples {
      ToolbarItem(placement: .topBarTrailing) {
        Menu(.editorSamples, systemImage: Constants.samples) { sampleButtons() }
      }
    }
  }

  @ViewBuilder
  private func sampleButtons() -> some View {
    Button(.editorSampleFull) {
      load(CommunityEditorSamples.completeSample)
      mode = .editor
    }
    Button(.editorSampleShort) { load(CommunityEditorSamples.short) }
    Button(.editorSampleBlocks) { load(CommunityEditorSamples.blockSample) }
    Button(.editorSampleParagraphs) { load(CommunityEditorSamples.paragraphSample) }
    Button(.editorSampleLists) { load(CommunityEditorSamples.listSample) }
    Button(.editorSampleEmpty) { load("") }
  }

  @ViewBuilder
  private func linkButton() -> some View {
    Button {
      viewModel.editLink()
    } label: {
      Image(systemName: Constants.link)
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  @ViewBuilder
  private func undoButton() -> some View {
    Button {
      viewModel.undo(undoManager)
    } label: {
      Image(systemName: Constants.undo)
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  @ViewBuilder
  private func redoButton() -> some View {
    Button {
      viewModel.redo(undoManager)
    } label: {
      Image(systemName: Constants.redo)
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
  }

  @ViewBuilder
  private func formatButton(_ format: CommunityEditorViewModel.Format) -> some View {
    Button {
      viewModel.toggle(format, undoManager: undoManager)
    } label: {
      Image(systemName: format.symbol)
        .frame(maxWidth: .infinity, minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
  }
}


private enum Constants {
  static let zero: CGFloat = 0
  static let contentSpacing: CGFloat = 12
  static let touchTarget: CGFloat = 44
  static let barPadding: CGFloat = 6
  static let barInset: CGFloat = 8
  // Match the editor's outer padding plus its native text-container insets.
  static let previewHorizontalInset: CGFloat = 17
  static let previewVerticalInset: CGFloat = 8
  static let selectedBackground = Color.primary.opacity(0.12)
  static let primary = Color.primary
  static let secondary = Color.secondary
  static let error = Color.red
  static let counterThreshold = 4000
  static let characterLimit = 4096
  static let link = "link"
  static let undo = "arrow.uturn.backward"
  static let redo = "arrow.uturn.forward"
  static let samples = "doc.on.doc"
}
