import CommunityEditorFeature
import SwiftUI

public struct CommunityComposerView: View {
  @Bindable private var model: CommunityComposerViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var confirmsClose = false
  @State private var showsDraftError = false
  @State private var confirmsDiscard = false

  public init(model: CommunityComposerViewModel) { self.model = model }

  public var body: some View {
    contentView()
  }
}

private extension CommunityComposerView {

  private func contentView() -> some View {
    composerNavigation()
      .interactiveDismissDisabled()
      .task { await model.restore() }
      .onChange(of: scenePhase) {
        if scenePhase != .active { model.perform { _ = await model.flushDraft() } }
      }
      .onDisappear { model.stop() }
      .alert(.composerUnsavedTitle, isPresented: $showsDraftError) {
        Button(.commonOk, role: .cancel) {}
      } message: {
        if let error = model.draftError { Text(error) }
      }
  }

  private func composerNavigation() -> some View {
    composerScreen()
      .confirmationDialog(
        .composerUnsavedTitle, isPresented: $confirmsClose, titleVisibility: .visible
      ) {
        Button(.composerCloseUnsaved, role: .destructive) { dismiss() }
        Button(.commonStay, role: .cancel) {}
      }
      .confirmationDialog(
        .composerUncertainTitle, isPresented: $model.needsRetryConfirmation, titleVisibility: .visible
      ) {
        Button(.composerRetry) { publish(confirmedRetry: true) }
        Button(.commonCancel, role: .cancel) {}
      } message: {
        Text(.composerRetryMessage)
      }
  }

  private func composerScreen() -> some View {
    NavigationStack {
      editorContentView()
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent() }
    }
  }

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .principal) { titleView() }
    ToolbarItem(placement: .topBarLeading) { closeButton() }
    ToolbarSpacer(.fixed, placement: .topBarLeading)
    ToolbarItem(placement: .topBarLeading) {
      if !model.editor.markdown.isEmpty { discardButton() }
    }
    ToolbarSpacer(.fixed, placement: .topBarTrailing)
    ToolbarItem(placement: .confirmationAction) { submitButton() }
  }

  private func titleView() -> some View {
    VStack(spacing: Constants.titleSpacing) {
      Text(model.title).font(.headline).lineLimit(1)
      draftStatusView()
    }
  }

  private func closeButton() -> some View {
    Button(.commonClose, systemImage: Constants.close, action: close)
      .disabled(!controlsEnabled)
      .accessibilityIdentifier("community.closeComposer")
  }

  private func discardButton() -> some View {
    Button(.composerDeleteDraft, systemImage: Constants.delete, role: .destructive) {
      confirmsDiscard = true
    }
    .disabled(!controlsEnabled)
    .accessibilityIdentifier("community.discardDraft")
    .confirmationDialog(
      .composerDeleteDraftTitle, isPresented: $confirmsDiscard, titleVisibility: .visible
    ) {
      Button(.postDelete, role: .destructive, action: discard)
      Button(.commonCancel, role: .cancel) {}
    }
  }

  private func submitButton() -> some View {
    Button { publish() } label: {
      if model.isPublishing { ProgressView() }
      else { Label(.composerPublish, systemImage: Constants.publish) }
    }
    .disabled(!controlsEnabled || !model.canPublish)
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .tint(Constants.publishTint)
    .accessibilityLabel(.composerPublish)
    .accessibilityIdentifier("community.publish")
  }

  private var controlsEnabled: Bool {
    model.isReady && !model.isPerformingAction && !model.isPublishing
  }

  private func close() {
    model.perform {
      if await model.flushDraft() { dismiss() } else { confirmsClose = true }
    }
  }

  private func discard() {
    model.perform { if await model.discard() { dismiss() } }
  }

  private func publish(confirmedRetry: Bool = false) {
    model.perform {
      await model.publish(confirmedRetry: confirmedRetry)
      if model.published != nil { dismiss() }
    }
  }

  @ViewBuilder
  private func editorContentView() -> some View {
    VStack(spacing: Constants.spacing) {
      if let error = model.publicationError {
        Text(error).font(.callout).foregroundStyle(Constants.error).padding(.horizontal)
      }
      if model.isReady {
        CommunityEditorView(viewModel: model.editor)
          .disabled(model.isPerformingAction || model.isPublishing || model.published != nil)
      } else {
        ProgressView(
          .composerRestoring
        ).frame(maxHeight: .infinity)
      }
    }
  }

  private func draftStatusView() -> some View {
    ZStack {
      Text(.composerSaved)
        .font(.caption2)
        .foregroundStyle(Constants.secondary)
        .lineLimit(1)
        .opacity(showsSavedStatus ? Constants.visible : Constants.hidden)
        .accessibilityHidden(!showsSavedStatus)
        .animation(
          reduceMotion ? nil : .easeInOut(duration: Constants.statusDuration),
          value: showsSavedStatus
        )
      Button { showsDraftError = true } label: {
        Text(.composerUnsavedTitle)
          .font(.caption2)
          .foregroundStyle(Constants.warning)
          .lineLimit(1)
      }
      .buttonStyle(.plain)
      .opacity(model.draftError == nil ? Constants.hidden : Constants.visible)
      .allowsHitTesting(model.draftError != nil)
      .accessibilityHidden(model.draftError == nil)
    }
  }

  private var showsSavedStatus: Bool {
    model.showsSavedNotice && model.draftError == nil
  }
}

private enum Constants {
  static let titleSpacing: CGFloat = 2
  static let close = "xmark"
  static let delete = "trash"
  static let publish = "arrow.up"
  static let publishTint = Color.blue
  static let spacing: CGFloat = 8
  static let statusDuration = 0.2
  static let visible = 1.0
  static let hidden = 0.0
  static let error = Color.red
  static let warning = Color.orange
  static let secondary = Color.secondary
}
