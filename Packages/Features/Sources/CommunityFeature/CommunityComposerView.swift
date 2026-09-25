import CommunityEditorFeature
import CommunityService
import Foundation
import SwiftUI

public struct CommunityComposerView: View {
  @Bindable private var model: CommunityComposerViewModel
  private let onPublished: (PostDescriptor, String, LocalizedStringResource?) async -> Void
  private let title: LocalizedStringResource
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var confirmsDiscard = false
  @State private var confirmsRetry = false
  @State private var confirmsClose = false
  @State private var showsDraftError = false

  public init(
    model: CommunityComposerViewModel, title: LocalizedStringResource? = nil,
    onPublished: @escaping (PostDescriptor, String, LocalizedStringResource?) async -> Void
  ) {
    self.model = model
    self.onPublished = onPublished
    self.title = title ?? .composerTitle
  }

  public var body: some View {
    contentView()
  }
}

private extension CommunityComposerView {

  @ViewBuilder
  private func contentView() -> some View {
    composerNavigation()
      .interactiveDismissDisabled()
      .task { await model.restore() }
      .onChange(of: model.editor.markdown) { model.textChanged() }
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
    NavigationStack {
      retryConfirmationContent()
    }
    .confirmationDialog(
      .composerUnsavedTitle, isPresented: $confirmsClose, titleVisibility: .visible
    ) {
      Button(.composerCloseUnsaved, role: .destructive) { dismiss() }
      Button(.commonStay, role: .cancel) {}
    }
  }

  private func retryConfirmationContent() -> some View {
    editorContentWithToolbar()
      .confirmationDialog(
        .composerUncertainTitle, isPresented: $confirmsRetry,
        titleVisibility: .visible
      ) {
        Button(
          .composerRetry, action: publish)
        Button(
          .commonCancel, role: .cancel
        ) {}
      } message: {
        Text(.composerRetryMessage)
      }
  }

  private func editorContentWithToolbar() -> some View {
    editorContentView()
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent() }
  }

  private func requestPublish() {
    if model.requiresRetryConfirmation { confirmsRetry = true } else { publish() }
  }

  private func publish() {
    model.perform {
      await model.publish()
      if let descriptor = model.published {
        await onPublished(descriptor, model.editor.markdown, model.draftError)
        dismiss()
      }
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

  @ToolbarContentBuilder
  private func toolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .principal) {
      titleView()
    }
    ToolbarItem(placement: .cancellationAction) {
      Button(
        .commonClose,
        systemImage: Constants.close
      ) {
        model.perform {
          if await model.flushDraft() { dismiss() } else { confirmsClose = true }
        }
      }
      .disabled(model.isPerformingAction || model.isPublishing || !model.isReady)
    }
    ToolbarItemGroup(placement: .topBarTrailing) {
      if !model.editor.markdown.isEmpty {
        discardButton()
      }
      publishButton()
    }
  }

  private func titleView() -> some View {
    VStack(spacing: Constants.titleSpacing) {
      Text(title).font(.headline).lineLimit(1)
      draftStatusView()
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

  private func publishButton() -> some View {
    Button(action: requestPublish) {
      if model.isPublishing {
        ProgressView()
      } else {
        Label(
          .composerPublish,
          systemImage: Constants.publish)
      }
    }
    .disabled(model.isPerformingAction || !model.canPublish)
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .tint(Constants.publishTint)
    .accessibilityLabel(
      .composerPublish)
  }

  private func discardButton() -> some View {
    Button(
      .composerDeleteDraft,
      systemImage: Constants.delete, role: .destructive
    ) { confirmsDiscard = true }
    .disabled(model.isPerformingAction || model.isPublishing || !model.isReady)
    .confirmationDialog(
      .composerDeleteDraftTitle,
      isPresented: $confirmsDiscard, titleVisibility: .visible
    ) {
      Button(.postDelete, role: .destructive) {
        model.perform { if await model.discard() { dismiss() } }
      }
      Button(.commonCancel, role: .cancel) {}
    }
  }

}

private enum Constants {
  static let spacing: CGFloat = 8
  static let titleSpacing: CGFloat = 2
  static let statusDuration = 0.2
  static let visible = 1.0
  static let hidden = 0.0
  static let error = Color.red
  static let warning = Color.orange
  static let secondary = Color.secondary
  static let close = "xmark"
  static let publish = "arrow.up"
  static let publishTint = Color.blue
  static let delete = "trash"
}
