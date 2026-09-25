import CommunityEditorFeature
import SwiftUI

struct CommunityReplyEditorView: View {
  @Bindable var model: CommunityPostDetailViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View { contentView() }
}

private extension CommunityReplyEditorView {
  private func contentView() -> some View {
    NavigationStack {
      CommunityEditorView(viewModel: model.editor)
        .navigationTitle(.postReply)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent() }
    }
    .onChange(of: model.editor.markdown) { model.editorChanged() }
    .onDisappear { model.collapseEditor() }
    .interactiveDismissDisabled(model.isSending)
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(.commonClose, systemImage: Constants.close) {
        model.collapseEditor()
        dismiss()
      }
    }
    ToolbarItem(placement: .topBarTrailing) {
      if model.isSending {
        ProgressView()
          .frame(width: Constants.controlSize, height: Constants.controlSize)
          .accessibilityLabel(.postSending)
      } else {
        sendButton()
      }
    }
  }

  private func sendButton() -> some View {
    Button(action: send) {
      Image(systemName: Constants.send)
        .frame(width: Constants.symbolSize, height: Constants.symbolSize)
    }
    .accessibilityLabel(.composerPublish)
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .disabled(!model.editor.canPublish)
  }

  private func send() {
    guard !model.isSending else { return }
    model.editorChanged()
    Task { await model.send() }
  }
}

private enum Constants {
  static let close = "xmark"
  static let send = "arrow.up"
  static let symbolSize: CGFloat = 20
  static let controlSize: CGFloat = 44
}
