import CommunityEditorFeature
import Foundation
import SwiftUI

struct CommunityEditView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var confirmsClose = false
  @State private var confirmsRetry = false
  let model: CommunityEditViewModel

  var body: some View {
    contentView()
  }
}

private extension CommunityEditView {

  @ViewBuilder
  private func contentView() -> some View {
    NavigationStack {
      editorNavigationContent()
    }
    .interactiveDismissDisabled(model.hasChanges || model.isSaving)
    .confirmationDialog(
      .editDiscardTitle,
      isPresented: $confirmsClose, titleVisibility: .visible
    ) {
      Button(
        .composerCloseUnsaved,
        role: .destructive
      ) { dismiss() }
      Button(
        .editContinue,
        role: .cancel
      ) {}
    } message: {
      Text(.editDiscardMessage)
    }
    .onChange(of: model.isSaved) {
      if model.isSaved { dismiss() }
    }
    .onDisappear { model.stop() }
  }

  private func editorNavigationContent() -> some View {
    editorContentView()
      .navigationTitle(.editTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent() }
      .confirmationDialog(
        .editRetryTitle,
        isPresented: $confirmsRetry, titleVisibility: .visible
      ) {
        Button(
          .editRetry,
          action: save)
        Button(
          .commonCancel, role: .cancel
        ) {}
      } message: {
        Text(.editRetryMessage)
      }
  }

  private func save() {
    model.requestSave()
  }

  @ViewBuilder
  private func editorContentView() -> some View {
    VStack(spacing: Constants.spacing) {
      if let error = model.error {
        Text(error).font(.callout).foregroundStyle(Constants.error).padding(.horizontal)
      }
      CommunityEditorView(viewModel: model.editor)
        .disabled(model.isSaving || model.isSaved)
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(
        .commonClose,
        systemImage: Constants.close
      ) {
        if model.hasChanges { confirmsClose = true } else { dismiss() }
      }
      .disabled(model.isSaving)
    }
    ToolbarItem(placement: .confirmationAction) {
      Button {
        if model.requiresRetryConfirmation { confirmsRetry = true } else { save() }
      } label: {
        if model.isSaving {
          ProgressView()
        } else {
          Label(
            .editSave,
            systemImage: Constants.save)
        }
      }
      .disabled(!model.canSave)
      .accessibilityLabel(
        .editSaveHint)
    }
  }

}

private enum Constants {
  static let spacing: CGFloat = 8
  static let error = Color.red
  static let close = "xmark"
  static let save = "checkmark"
}
