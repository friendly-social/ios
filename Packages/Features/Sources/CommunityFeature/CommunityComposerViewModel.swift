import CommunityEditorFeature
import CommunityDraftService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
public final class CommunityComposerViewModel: Identifiable {
  public let id = UUID()
  public let editor = CommunityEditorViewModel(source: "")
  public private(set) var isReady = false
  public private(set) var isPublishing = false
  public private(set) var published: PostDescriptor?
  public private(set) var publicationError: LocalizedStringResource?
  public private(set) var draftError: LocalizedStringResource?
  public private(set) var draftSaved = false
  public private(set) var showsSavedNotice = false
  public private(set) var requiresRetryConfirmation = false
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  @ObservationIgnored @Dependency(CommunityDraftService.self) private var draftService
  private var drafts: CommunityDrafts?
  private var isCurrentSession: () -> Bool = { false }
  private var onUnauthorized: () -> Void
  private var saveTask: Task<Void, Never>?
  private var actionTask: Task<Void, Never>?
  private var noticeTask: Task<Void, Never>?
  private var observedText = ""
  private var replyTarget: PostDescriptor?
  private var suppressDraft: (String) -> Bool = { _ in false }
  private var didSaveDraft: (String) -> Void = { _ in }

  public init(
    replyTo target: PostDescriptor? = nil,
    suppressDraft: @escaping (String) -> Bool = { _ in false },
    didSaveDraft: @escaping (String) -> Void = { _ in },
    onUnauthorized: @escaping () -> Void
  ) {
    self.replyTarget = target
    self.suppressDraft = suppressDraft
    self.didSaveDraft = didSaveDraft
    self.onUnauthorized = onUnauthorized
  }

  @discardableResult
  public func start() -> Bool {
    guard let session = profileService.currentSession() else { return false }
    let profile = profileService
    let draftService = draftService
    let isCurrent: @Sendable () -> Bool = { profile.isCurrentSession(session) }
    var drafts = replyTarget.map {
      draftService.replyDrafts($0, session.accountID, session.sessionID, isCurrent)
    } ?? draftService.postDrafts(session.accountID, session.sessionID, isCurrent)
    if replyTarget == nil {
      let original = drafts
      drafts.load = { [weak self] in
        guard let source = try await original.load(), self?.suppressDraft(source) != true else {
          return nil
        }
        return source
      }
      drafts.save = { [weak self] text in
        try await original.save(text)
        self?.didSaveDraft(text)
      }
    }
    self.drafts = drafts
    isCurrentSession = isCurrent
    let callback = onUnauthorized
    onUnauthorized = {
      profile.clearSession()
      callback()
    }
    return true
  }

  public var canPublish: Bool {
    isReady && !isPublishing && published == nil && editor.canPublish && isCurrentSession()
  }

  public var isPerformingAction: Bool { actionTask != nil }

  public func restore() async {
    guard !isReady, let drafts else { return }
    do {
      let source = try await drafts.load()
      guard isCurrentSession(), !Task.isCancelled else { return }
      if let source {
        editor.loadSource(source)
        draftSaved = true
      }
    } catch {
      guard isCurrentSession(), !Task.isCancelled else { return }
      draftError = .composerRestoreError
    }
    observedText = editor.markdown
    isReady = true
  }

  public func textChanged() {
    guard isReady, !isPublishing, published == nil, isCurrentSession() else { return }
    let text = editor.markdown
    guard text != observedText else { return }
    observedText = text
    hideSavedNotice()
    draftSaved = false
    let previous = saveTask
    previous?.cancel()
    saveTask = Task { [weak self] in
      await previous?.value
      do { try await Task.sleep(for: Constants.autosaveDelay) } catch { return }
      guard !Task.isCancelled else { return }
      await self?.save(text)
      guard !Task.isCancelled else { return }
      self?.showSavedNotice(for: text)
    }
  }

  @discardableResult
  public func flushDraft() async -> Bool {
    let previous = saveTask
    previous?.cancel()
    await previous?.value
    saveTask = nil
    guard isReady, published == nil, isCurrentSession() else { return published != nil }
    await save(editor.markdown)
    return draftError == nil
  }

  public func publish() async {
    guard canPublish else { return }
    isPublishing = true
    publicationError = nil
    requiresRetryConfirmation = false
    let text = editor.markdown
    defer { isPublishing = false }
    _ = await flushDraft()
    guard isCurrentSession(), !Task.isCancelled else { return }
    do {
      let descriptor = try await publish(text)
      guard isCurrentSession() else { return }
      published = descriptor
      await removePublishedDraft()
    } catch CommunityError.unauthorized {
      guard isCurrentSession() else { return }
      publicationError = .sessionExpired
      onUnauthorized()
    } catch CommunityError.rejected(let status) {
      guard isCurrentSession() else { return }
      publicationError = .composerRejected(status)
    } catch {
      guard isCurrentSession() else { return }
      requiresRetryConfirmation = true
      publicationError = .composerUncertain
    }
  }

  private func publish(_ text: String) async throws -> PostDescriptor {
    if let replyTarget { return try await service.reply(replyTarget, text) }
    return try await service.publish(text)
  }

  public func discard() async -> Bool {
    guard !isPublishing, let drafts else { return false }
    hideSavedNotice()
    saveTask?.cancel()
    await saveTask?.value
    do {
      try await drafts.remove()
      guard isCurrentSession() else { return false }
      editor.loadSource("")
      draftSaved = false
      draftError = nil
      return true
    } catch {
      draftError = .composerDeleteError
      return false
    }
  }

  public func perform(_ action: @escaping @MainActor () async -> Void) {
    guard actionTask == nil else { return }
    actionTask = Task { [weak self] in
      await action()
      self?.actionTask = nil
    }
  }

  public func stop() {
    hideSavedNotice()
    saveTask?.cancel()
    actionTask?.cancel()
  }
}

private extension CommunityComposerViewModel {
  private func removePublishedDraft() async {
    guard let drafts else { return }
    do {
      try await drafts.remove()
      draftError = nil
    } catch {
      draftError = .composerCleanupError
    }
  }

  private func hideSavedNotice() {
    noticeTask?.cancel()
    noticeTask = nil
    showsSavedNotice = false
  }

  private func showSavedNotice(for text: String) {
    guard draftSaved, draftError == nil, editor.markdown == text,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      isCurrentSession(), !isPublishing, published == nil else { return }
    showsSavedNotice = true
    noticeTask = Task { [weak self] in
      do { try await Task.sleep(for: Constants.noticeDuration) } catch { return }
      self?.showsSavedNotice = false
    }
  }

  private func save(_ text: String) async {
    guard let drafts, published == nil, isCurrentSession() else { return }
    do {
      try await drafts.save(text)
      guard isCurrentSession() else { return }
      draftError = nil
      draftSaved = editor.markdown == text
    } catch {
      guard isCurrentSession() else { return }
      draftError = .composerSaveError
    }
  }
}

private enum Constants {
  static let autosaveDelay: Duration = .seconds(1)
  static let noticeDuration: Duration = .seconds(2)
}
