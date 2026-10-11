import CommunityDraftService
import CommunityEditorFeature
import CommunityMarkdownService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
final class CommunityPostDetailViewModel {
  private(set) var post: CommunityPost
  private(set) var selectedRow: CommunityFeedPost?
  private(set) var upstream: [CommunityPost] = []
  private(set) var ancestorRows: [CommunityFeedPost] = []
  private(set) var replies: [CommunityPost] = []
  private(set) var replyRows: [CommunityFeedPost] = []
  private(set) var pendingReplies: [CommunityPost] = []
  private(set) var pendingRows: [CommunityFeedPost] = []
  private(set) var scrollToReplyID: Int64?
  private(set) var nextID: String?
  private(set) var isLoading = false
  private(set) var isLoadingMore = false
  private(set) var isSending = false
  private(set) var loaded = false
  var loadError: LocalizedStringResource?
  var pageError: LocalizedStringResource?
  var sendError: LocalizedStringResource?
  var mutationError: LocalizedStringResource?
  var editingPost: CommunityEditViewModel?
  private(set) var deletingID: Int64?
  var draft: CommunityReplyDraft = .plainText("")
  var editor = CommunityEditorViewModel()
  var showsEditor = false
  private var editorTarget: CommunityPost?
  private var editorDraft: CommunityReplyDraft = .plainText("")
  var needsRetryConfirmation = false
  private(set) var requiresRetryConfirmation = false
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  @ObservationIgnored @Dependency(CommunityDraftService.self) private var draftService
  @ObservationIgnored @Dependency(CommunityFeedPreparationService.self) private var preparation
  private var accountID: Int64?
  private let onMutation: (CommunityPost) async -> Void
  private var draftStore: ((PostDescriptor) -> CommunityReplyDrafts)?
  private var currentUser: () async -> CommunityPost.Owner? = { nil }
  private var isCurrentSession: () -> Bool = { false }
  private var onUnauthorized: () -> Void
  private var generation = 0
  private var hasRestored = false
  private var saveTask: Task<Void, Never>?
  private var snapshots: [Int64: DiscussionSnapshot] = [:]
  private var initialOwner: CommunityPost.Owner?
  private var initialDetails: CommunityPostDetails?
  private let focusedReply: PostDescriptor?
  private let focusedParent: PostDescriptor
  private(set) var currentOwner: CommunityPost.Owner?

  init(
    post: CommunityPost,
    selectedRow: CommunityFeedPost? = nil,
    currentOwner: CommunityPost.Owner? = nil,
    initialDetails: CommunityPostDetails? = nil,
    focusedReply: PostDescriptor? = nil,
    onUnauthorized: @escaping () -> Void,
    onMutation: @escaping (CommunityPost) async -> Void = { _ in }
  ) {
    self.post = post
    self.selectedRow = selectedRow
    self.initialOwner = currentOwner
    self.initialDetails = initialDetails
    self.focusedReply = focusedReply
    self.focusedParent = post.descriptor
    self.onMutation = onMutation
    self.onUnauthorized = onUnauthorized
  }

  @discardableResult
  func start() -> Bool {
    if accountID != nil { return true }
    guard let session = profileService.currentSession() else { return false }
    let profile = profileService
    let draftService = draftService
    let isCurrent: @Sendable () -> Bool = { profile.isCurrentSession(session) }
    draftStore = { draftService.detailDrafts($0, session.accountID, session.sessionID, isCurrent) }
    accountID = session.accountID
    currentOwner = initialOwner ?? profile.cachedOwner(session)
    let owner = initialOwner
    currentUser = {
      if let owner { return owner }
      return try? await profile.loadOwner(session)
    }
    isCurrentSession = isCurrent
    let callback = onUnauthorized
    onUnauthorized = {
      profile.clearSession()
      callback()
    }
    return true
  }

  func activate() async {
    guard start() else { return }
    async let replies: Void = load()
    async let draft: Void = restore()
    _ = await (replies, draft)
  }

  func avatarURL(_ avatar: CommunityPost.Owner.Avatar) -> URL {
    profileService.avatarURL(avatar)
  }

  var plainText: String {
    get { if case let .plainText(text) = draft { return text }; return "" }
    set { changeDraft(.plainText(newValue)) }
  }

  var payload: String {
    markdown(for: draft)
  }

  var canSend: Bool {
    let text = showsEditor ? markdown(for: editorDraft) : payload
    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && text.utf16.count <= Constants.limit && !isSending
  }

  func canManage(_ item: CommunityPost) -> Bool {
    guard let accountID, isCurrentSession() else { return false }
    switch item {
    case let .published(post): return post.owner.id == accountID
    case .awaitingDetails: return true
    case .deleted: return false
    }
  }

  func edit(_ item: CommunityPost) {
    guard canManage(item), deletingID == nil else { return }
    withDependencies(from: self) {
      let model = CommunityEditViewModel(
        post: item,
        onUnauthorized: onUnauthorized,
        onSaved: { [weak self] updated in await self?.replace(updated) })
      model.start()
      editingPost = model
    }
  }

  func delete(_ item: CommunityPost) async {
    guard canManage(item), deletingID == nil else { return }
    deletingID = item.id
    mutationError = nil
    defer { deletingID = nil }
    do {
      try await service.delete(item.id)
      guard isCurrentSession() else { return }
      let deleted = CommunityPost.deleted(.init(
        descriptor: item.descriptor, date: item.date ?? .now,
        replyPreviews: item.replyPreviews))
      await replace(deleted)
    } catch CommunityError.unauthorized {
      if isCurrentSession() { onUnauthorized() }
    } catch CommunityError.rejected(let status) {
      mutationError = status == 404 ? .postDeleteUnavailable : .postDeleteRejected(status)
    } catch {
      mutationError = .postDeleteUncertain
    }
  }

  func restore() async {
    guard !hasRestored, let draftStore else { return }
    hasRestored = true
    let descriptor = post.descriptor
    do {
      if let restored = try await draftStore(descriptor).load(), isCurrentSession(),
         post.id == descriptor.id, draft.text.isEmpty {
        draft = restored
      }
    } catch { sendError = .postDraftError }
  }

  func load() async {
    guard !isLoading, isCurrentSession() else { return }
    generation += 1
    let request = generation
    isLoading = true
    loadError = nil
    defer { if generation == request { isLoading = false } }
    do {
      let details = try await fetchedDetails()
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      applyDetails(details)
      try await prepareDetails(details, generation: request)
    } catch CommunityError.unauthorized {
      if isCurrentSession() { onUnauthorized() }
    } catch is CancellationError {
    } catch {
      if isCurrentSession() { loadError = .postRepliesLoadError }
    }
  }

  func select(_ item: CommunityPost) {
    guard item.id != post.id else { return }
    let previousDescriptor = post.descriptor
    let previousDraft = draft
    Task { await persist(previousDraft, for: previousDescriptor) }
    let lineage = upstream + [post]
    if loaded { snapshots[post.id] = snapshot() }
    let cached = snapshots[item.id]
    let nextRow = (ancestorRows + replyRows + pendingRows).first { $0.id == item.id }
    if let index = lineage.firstIndex(where: { $0.id == item.id }) {
      upstream = Array(lineage.prefix(upTo: index))
      ancestorRows = Array(ancestorRows.prefix(index))
    } else {
      upstream = lineage
      ancestorRows.append(selectedRow ?? CommunityFeedPost(
        post: post, content: .init(source: post.text, excerpt: nil)))
    }
    post = item
    selectedRow = nextRow
    resetSelection()
    if let cached { restore(cached) }
  }

  func loadMore() async {
    guard let cursor = nextID, !isLoadingMore, !isLoading, isCurrentSession() else { return }
    let request = generation
    isLoadingMore = true
    pageError = nil
    defer { isLoadingMore = false }
    do {
      let page = try await service.replies(post.descriptor, cursor)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      let merged = deduplicated(replies + page.data.compactMap(\.directPost))
      let prepared = try await preparation.prepare(merged, reusing: replyRows)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      replies = merged
      replyRows = prepared
      pendingReplies.removeAll { pending in replies.contains { $0.id == pending.id } }
      pendingRows.removeAll { pending in replies.contains { $0.id == pending.id } }
      nextID = page.nextId
    } catch CommunityError.unauthorized {
      if isCurrentSession() { onUnauthorized() }
    } catch is CancellationError {
    } catch {
      if isCurrentSession() { pageError = .postRepliesLoadError }
    }
  }

  func expandEditor() {
    openEditor(for: post, draft: draft)
  }

  func reply(to item: CommunityPost) {
    guard !showsEditor, !isSending else { return }
    if item.id == post.id {
      expandEditor()
      return
    }
    saveTask?.cancel()
    let currentDraft = draft
    let currentDescriptor = post.descriptor
    Task { await persist(currentDraft, for: currentDescriptor) }
    openEditor(for: item, draft: .plainText(""))
    Task { await restoreEditorDraft(for: item.descriptor) }
  }

  func collapseEditor() {
    guard showsEditor else { return }
    editorChanged()
    guard let target = editorTarget else { return }
    if target.id == post.id { draft = editorDraft }
    Task { await persist(editorDraft, for: target.descriptor) }
    editorTarget = nil
    showsEditor = false
  }

  func editorChanged() {
    guard showsEditor, let target = editorTarget,
          editor.markdown != markdown(for: editorDraft) else { return }
    editorDraft = draftService.replyDraft(editor.markdown)
    scheduleSave(editorDraft, for: target.descriptor)
  }

  func changeDraft(_ value: CommunityReplyDraft) {
    draft = value
    sendError = nil
    requiresRetryConfirmation = false
    scheduleSave(value, for: post.descriptor)
  }

  func saveDraft() async {
    if showsEditor, let editorTarget {
      await persist(editorDraft, for: editorTarget.descriptor)
    } else {
      await persist(draft, for: post.descriptor)
    }
  }

  func send(confirmedRetry: Bool = false) async {
    guard canSend, isCurrentSession(), let draftStore else { return }
    if requiresRetryConfirmation && !confirmedRetry {
      needsRetryConfirmation = true
      return
    }
    let targetPost = showsEditor ? (editorTarget ?? post) : post
    let target = targetPost.descriptor
    let text = showsEditor ? markdown(for: editorDraft) : payload
    isSending = true
    sendError = nil
    defer { isSending = false }
    do {
      let descriptor = try await service.reply(target, text)
      guard isCurrentSession() else { return }
      showsEditor = false
      do { try await draftStore(target).remove() } catch { sendError = .postDraftError }
      await showSentReply(descriptor, text: text, to: targetPost)
    } catch CommunityError.unauthorized {
      if isCurrentSession() { onUnauthorized() }
    } catch CommunityError.rejected(let status) {
      sendError = .postReplyRejected(status)
    } catch {
      requiresRetryConfirmation = true
      needsRetryConfirmation = true
      sendError = .postReplyUncertain
    }
  }

  func stop() {
    generation += 1
    saveTask?.cancel()
    Task { await saveDraft() }
  }
}

private extension CommunityPostDetailViewModel {
  private func fetchedDetails() async throws -> CommunityPostDetails {
    if let initialDetails, initialDetails.post.descriptor == post.descriptor {
      self.initialDetails = nil
      return initialDetails
    }
    initialDetails = nil
    let details = try await service.details(post.descriptor)
    return try await includingFocusedReply(in: details)
  }

  private func includingFocusedReply(in details: CommunityPostDetails) async throws -> CommunityPostDetails {
    guard details.post.descriptor == focusedParent, let focusedReply,
          !details.replies.data.contains(where: { $0.directPost?.id == focusedReply.id }) else { return details }
    let target: CommunityPostDetails
    do { target = try await service.details(focusedReply) }
    catch CommunityError.rejected(404) { return details }
    guard target.upstream.last?.descriptor == details.post.descriptor else { return details }
    let replies = CommunityReplyPage(
      data: details.replies.data + [.single(target.post)], nextId: details.replies.nextId)
    return .init(post: details.post, upstream: details.upstream, replies: replies)
  }

  private func applyDetails(_ details: CommunityPostDetails) {
    let previous = ancestorRows + replyRows + (selectedRow.map { [$0] } ?? [])
    post = details.post
    selectedRow = row(post, reusing: previous)
    upstream = details.upstream
    ancestorRows = upstream.map { row($0, reusing: previous) }
    replies = deduplicated(details.replies.data.compactMap(\.directPost))
    replyRows = replies.map { row($0, reusing: previous) }
    nextID = details.replies.nextId
  }

  private func row(_ post: CommunityPost, reusing previous: [CommunityFeedPost]) -> CommunityFeedPost {
    if let cached = previous.first(where: { $0.id == post.id && $0.content.source == post.text }) {
      return CommunityFeedPost(post: post, content: cached.content)
    }
    return CommunityFeedPost(post: post, content: .init(source: post.text, excerpt: nil))
  }

  private func prepareDetails(_ details: CommunityPostDetails, generation request: Int) async throws {
    let ancestors = try await preparation.prepare(details.upstream, reusing: ancestorRows)
    let preparedReplies = try await preparation.prepare(replies, reusing: replyRows)
    let selected = await preparation.prepare(details.post)
    guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
    selectedRow = selected
    ancestorRows = ancestors
    replyRows = preparedReplies
    pendingReplies.removeAll { pending in replies.contains { $0.id == pending.id } }
    pendingRows.removeAll { pending in replies.contains { $0.id == pending.id } }
    initialDetails = nil
    snapshots[post.id] = snapshot()
    loaded = true
  }

  private func markdown(for value: CommunityReplyDraft) -> String {
    switch value {
    case let .plainText(text): MarkdownLiteral.encode(text)
    case let .markdown(source): source
    }
  }

  private func openEditor(for item: CommunityPost, draft value: CommunityReplyDraft) {
    editorTarget = item
    editorDraft = value
    editor.loadSource(markdown(for: value))
    showsEditor = true
  }

  private func restoreEditorDraft(for descriptor: PostDescriptor) async {
    guard let draftStore else { return }
    do {
      guard let restored = try await draftStore(descriptor).load(),
            showsEditor, editorTarget?.id == descriptor.id,
            editorDraft.text.isEmpty, editor.markdown.isEmpty else { return }
      editorDraft = restored
      editor.loadSource(markdown(for: restored))
    } catch { sendError = .postDraftError }
  }

  private func scheduleSave(_ value: CommunityReplyDraft, for descriptor: PostDescriptor) {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(Constants.saveDelay))
      guard !Task.isCancelled else { return }
      await self?.persist(value, for: descriptor)
    }
  }

  private func showSentReply(
    _ descriptor: PostDescriptor, text: String, to target: CommunityPost
  ) async {
    let owner = await currentUser()
    let reply = CommunityPost.awaitingDetails(.init(
      descriptor: descriptor, text: text, owner: owner, date: .now))
    editorTarget = nil
    editorDraft = .plainText("")
    showsEditor = false
    requiresRetryConfirmation = false
    saveTask?.cancel()
    if target.id != post.id { select(target) } else { draft = .plainText("") }
    pendingReplies.append(reply)
    pendingRows.append(await preparation.prepare(reply))
    await load()
    snapshots[post.id] = snapshot()
    scrollToReplyID = descriptor.id
  }

  private func snapshot() -> DiscussionSnapshot {
    DiscussionSnapshot(
      post: post, selectedRow: selectedRow, upstream: upstream, ancestorRows: ancestorRows,
      replies: replies, replyRows: replyRows, pendingReplies: pendingReplies,
      pendingRows: pendingRows, nextID: nextID)
  }

  private func restore(_ snapshot: DiscussionSnapshot) {
    post = snapshot.post
    selectedRow = snapshot.selectedRow
    upstream = snapshot.upstream
    ancestorRows = snapshot.ancestorRows
    replies = snapshot.replies
    replyRows = snapshot.replyRows
    pendingReplies = snapshot.pendingReplies
    pendingRows = snapshot.pendingRows
    nextID = snapshot.nextID
    loaded = true
  }

  private func persist(_ value: CommunityReplyDraft, for descriptor: PostDescriptor) async {
    guard let draftStore else { return }
    do {
      let drafts = draftStore(descriptor)
      if value.text.isEmpty { try await drafts.remove() } else { try await drafts.save(value) }
    } catch { sendError = .postDraftError }
  }

  private func resetSelection() {
    generation += 1
    isLoading = false
    isLoadingMore = false
    loaded = false
    loadError = nil
    pageError = nil
    replies = []
    replyRows = []
    pendingReplies = []
    pendingRows = []
    nextID = nil
    draft = .plainText("")
    hasRestored = false
    saveTask?.cancel()
  }

  private func replace(_ updated: CommunityPost) async {
    guard isCurrentSession() else { return }
    snapshots.removeAll()
    if post.id == updated.id { post = updated }
    upstream = upstream.map { $0.id == updated.id ? updated : $0 }
    replies = replies.map { $0.id == updated.id ? updated : $0 }
    pendingReplies = pendingReplies.map { $0.id == updated.id ? updated : $0 }
    if let prepared = try? await preparation.prepare(upstream, reusing: ancestorRows) {
      ancestorRows = prepared
    }
    if let prepared = try? await preparation.prepare(replies, reusing: replyRows) {
      replyRows = prepared
    }
    if let prepared = try? await preparation.prepare(pendingReplies, reusing: pendingRows) {
      pendingRows = prepared
    }
    await onMutation(updated)
  }

  private func deduplicated(_ posts: [CommunityPost]) -> [CommunityPost] {
    var order: [Int64] = []
    var latest: [Int64: CommunityPost] = [:]
    for post in posts {
      if latest[post.id] == nil { order.append(post.id) }
      latest[post.id] = post
    }
    return order.compactMap { latest[$0] }
  }
}

private struct DiscussionSnapshot {
  let post: CommunityPost
  let selectedRow: CommunityFeedPost?
  let upstream: [CommunityPost]
  let ancestorRows: [CommunityFeedPost]
  let replies: [CommunityPost]
  let replyRows: [CommunityFeedPost]
  let pendingReplies: [CommunityPost]
  let pendingRows: [CommunityFeedPost]
  let nextID: String?
}

private enum Constants {
  static let limit = 4_096
  static let saveDelay = 800
}
