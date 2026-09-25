import CommunityEditorFeature
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
public final class CommunityEditViewModel: Identifiable {
  public let editor: CommunityEditorViewModel
  public private(set) var isSaving = false
  public private(set) var isSaved = false
  public private(set) var error: LocalizedStringResource?
  public private(set) var requiresRetryConfirmation = false
  private let post: CommunityPost
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  private var isCurrentSession: () -> Bool = { false }
  private var onUnauthorized: () -> Void
  private let onSaved: (CommunityPost) async -> Void
  private var saveTask: Task<Void, Never>?

  public init(
    post: CommunityPost,
    onUnauthorized: @escaping () -> Void = {},
    onSaved: @escaping (CommunityPost) async -> Void = { _ in }
  ) {
    self.post = post
    self.onUnauthorized = onUnauthorized
    self.onSaved = onSaved
    editor = CommunityEditorViewModel(source: post.text ?? "")
  }

  func start() {
    let profile = profileService
    let session = profile.currentSession()
    isCurrentSession = { session.map(profile.isCurrentSession) ?? false }
    let callback = onUnauthorized
    onUnauthorized = {
      profile.clearSession()
      callback()
    }
  }

  public var hasChanges: Bool { editor.markdown != post.text }
  public var canSave: Bool {
    post.text != nil && hasChanges && editor.canPublish && !isSaving && !isSaved
      && isCurrentSession()
  }

  func requestSave() {
    guard saveTask == nil else { return }
    saveTask = Task {
      await saveButtonTapped()
      saveTask = nil
    }
  }

  func stop() {
    saveTask?.cancel()
  }

  public func saveButtonTapped() async {
    guard canSave, !Task.isCancelled else { return }
    isSaving = true
    error = nil
    requiresRetryConfirmation = false
    let text = editor.markdown
    defer { isSaving = false }
    do {
      try await service.edit(post.id, text)
      guard isCurrentSession() else { return }
      isSaved = true
      await onSaved(post.replacingText(text))
    } catch is CancellationError {
    } catch CommunityError.unauthorized {
      guard isCurrentSession() else { return }
      error = .sessionExpired
      onUnauthorized()
    } catch CommunityError.rejected(let status) {
      guard isCurrentSession() else { return }
      error =
        status == 404
        ? .editUnavailable
        : .editRejected(status)
    } catch {
      guard isCurrentSession() else { return }
      requiresRetryConfirmation = true
      self.error = .editUncertain
    }
  }
}
