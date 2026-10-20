import CommunityDraftService
import CommunityEditorFeature
import CommunityMarkdownService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation
import SwiftNavigation

@MainActor @Observable
public final class CommunityComposerViewModel: Identifiable {
  public let id = UUID()
  public let editor = CommunityEditorViewModel(source: "")
  public private(set) var isReady = false
  public private(set) var published: PostDescriptor?
  public private(set) var publicationError: LocalizedStringResource?
  public private(set) var draftError: LocalizedStringResource?
  public private(set) var draftSaved = false
  public private(set) var showsSavedNotice = false
  public private(set) var requiresRetryConfirmation = false
  public var needsRetryConfirmation = false
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  @ObservationIgnored @Dependency(CommunityDraftService.self) private var draftService
  private var operation = ComposerOperation.idle
  private var drafts: CommunityDrafts?
  private var isCurrentSession: () -> Bool = { false }
  private var onUnauthorized: () -> Void
  @ObservationIgnored private var saveTask: Task<Void, Never>?
  private var actionTask: Task<Void, Never>?
  @ObservationIgnored private var noticeTask: Task<Void, Never>?
  @ObservationIgnored private var restoreTask: Task<Void, Never>?
  @ObservationIgnored private var editorObservation: ObserveToken?
  private let onPublished: (PostDescriptor, String, LocalizedStringResource?) async -> Void
  @ObservationIgnored private var observedText = ""
  private let replyTarget: PostDescriptor?
  private let suppressDraft: (String) -> Bool
  private let didSaveDraft: (String) -> Void

  public init(
    replyTo target: PostDescriptor? = nil,
    suppressDraft: @escaping (String) -> Bool = { _ in false },
    didSaveDraft: @escaping (String) -> Void = { _ in },
    onUnauthorized: @escaping () -> Void,
    onPublished: @escaping (PostDescriptor, String, LocalizedStringResource?) async -> Void = { _, _, _ in }
  ) {
    self.replyTarget = target
    self.suppressDraft = suppressDraft
    self.didSaveDraft = didSaveDraft
    self.onUnauthorized = onUnauthorized
    self.onPublished = onPublished
  }

  @discardableResult
  public func start() -> Bool {
    if drafts != nil { return isCurrentSession() }
    guard let session = profileService.currentSession() else { return false }
    editor.start(session: session)
    let profile = profileService
    let draftService = draftService
    let isCurrent: @Sendable () -> Bool = { profile.isCurrentSession(session) }
    var drafts = replyTarget.map {
      draftService.replyDrafts($0, session.accountID, session.sessionID, isCurrent)
    } ?? draftService.postDrafts(session.accountID, session.sessionID, isCurrent)
    drafts = observingDrafts(drafts)
    self.drafts = drafts
    editorObservation = observe { @MainActor [weak self] in self?.textChanged() }
    isCurrentSession = isCurrent
    let callback = onUnauthorized
    onUnauthorized = {
      profile.clearSession()
      callback()
    }
    return true
  }

  public var canPublish: Bool {
    isReady && operation == .idle && published == nil && editor.canPublish && isCurrentSession()
  }

  public var isPublishing: Bool { operation == .publishing }

  public var isPerformingAction: Bool { actionTask != nil || operation == .discarding }

  public var title: LocalizedStringResource { replyTarget == nil ? .composerTitle : .postReply }

  var plainText: String? {
    if case let .plainText(text) = draftService.replyDraft(editor.markdown) { return text }
    return nil
  }

  func setPlainText(_ text: String) {
    guard isReady, operation == .idle else { return }
    editor.loadSource(MarkdownLiteral.encode(text))
    editor.restoreCursor(nil)
    textChanged()
  }

  public func restore() async {
    guard !isReady, let drafts else { return }
    if let restoreTask { await restoreTask.value; return }
    let task = Task { [weak self] in
      guard let self else { return }
      await restoreDraft(drafts)
    }
    restoreTask = task
    await task.value
    restoreTask = nil
  }

  public func textChanged() {
    guard isReady, operation == .idle, published == nil, isCurrentSession() else { return }
    let text = editor.markdown
    guard text != observedText else { return }
    observedText = text
    hideSavedNotice()
    draftSaved = false
    scheduleSave(text)
  }

  @discardableResult
  public func flushDraft() async -> Bool {
    guard isReady, operation != .discarding, published == nil, isCurrentSession() else { return published != nil }
    let previous = saveTask
    previous?.cancel()
    let task = Task { [weak self] in
      await previous?.value
      guard let self else { return }
      await saveCurrentDraft()
    }
    saveTask = task
    await task.value
    return isCurrentSession() && draftError == nil
  }

  public func publish(confirmedRetry: Bool = false) async {
    guard canPublish else { return }
    if requiresRetryConfirmation && !confirmedRetry {
      needsRetryConfirmation = true
      return
    }
    operation = .publishing
    publicationError = nil
    requiresRetryConfirmation = false
    needsRetryConfirmation = false
    let text = editor.markdown
    defer { operation = .idle }
    _ = await flushDraft()
    guard isCurrentSession(), !Task.isCancelled else { return }
    do {
      let descriptor = try await publish(text)
      guard isCurrentSession() else { return }
      published = descriptor
      await removePublishedDraft()
      guard isCurrentSession() else { return }
      await onPublished(descriptor, text, draftError)
    } catch { handlePublicationError(error) }
  }

  func dismissPublicationError() { publicationError = nil }

  public func discard() async -> Bool {
    guard isReady, operation == .idle, isCurrentSession(), let drafts else { return false }
    operation = .discarding
    defer { operation = .idle }
    hideSavedNotice()
    await cancelPendingSave()
    do {
      try await drafts.remove()
      guard isCurrentSession() else { return false }
      editor.loadSource("")
      observedText = ""
      requiresRetryConfirmation = false
      needsRetryConfirmation = false
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
    restoreTask?.cancel()
  }
}

private extension CommunityComposerViewModel {
  private func restoreDraft(_ drafts: CommunityDrafts) async {
    do {
      let source = try await drafts.load()
      guard isCurrentSession(), !Task.isCancelled else { return }
      if let source {
        editor.loadSource(source)
        editor.restoreCursor(nil)
        draftSaved = true
      }
    } catch {
      guard isCurrentSession(), !Task.isCancelled else { return }
      draftError = .composerRestoreError
    }
    observedText = editor.markdown
    isReady = true
  }

  private func publish(_ text: String) async throws -> PostDescriptor {
    if let replyTarget { return try await service.reply(replyTarget, text) }
    return try await service.publish(text)
  }

  private func handlePublicationError(_ error: Error) {
    guard isCurrentSession() else { return }
    switch error {
    case CommunityError.unauthorized:
      publicationError = .sessionExpired
      onUnauthorized()
    case let CommunityError.rejected(status): publicationError = .composerRejected(status)
    default:
      requiresRetryConfirmation = true
      publicationError = .composerUncertain
    }
  }

  private func observingDrafts(_ original: CommunityDrafts) -> CommunityDrafts {
    var drafts = original
    drafts.load = { [weak self] in
      guard let source = try await original.load(), self?.suppressDraft(source) != true else { return nil }
      return source
    }
    drafts.save = { [weak self] text in
      try await original.save(text)
      self?.didSaveDraft(text)
    }
    return drafts
  }

  private func scheduleSave(_ text: String) {
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

  private func saveCurrentDraft() async {
    guard isReady, published == nil, isCurrentSession() else { return }
    do { try await editor.prepareForSaving() } catch {
      draftError = .composerSaveError
      return
    }
    await save(editor.markdown)
  }

  private func cancelPendingSave() async {
    // Cancellation stops debounce; an in-flight write must finish before deletion.
    let previous = saveTask
    previous?.cancel()
    await previous?.value
    saveTask = nil
  }

  private func removePublishedDraft() async {
    guard let drafts else { return }
    await cancelPendingSave()
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

private enum ComposerOperation {
  case idle, publishing, discarding
}

private enum Constants {
  static let autosaveDelay: Duration = .seconds(1)
  static let noticeDuration: Duration = .seconds(2)
}
