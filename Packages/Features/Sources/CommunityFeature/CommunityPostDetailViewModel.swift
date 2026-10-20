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
  private(set) var loaded = false
  var loadError: LocalizedStringResource?
  var pageError: LocalizedStringResource?
  var sendError: LocalizedStringResource?
  var mutationError: LocalizedStringResource?
  var editingPost: CommunityEditViewModel?
  private(set) var replyComposer: CommunityComposerViewModel?
  var composer: CommunityComposerViewModel?
  private(set) var deletingID: Int64?
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  @ObservationIgnored @Dependency(CommunityFeedPreparationService.self) private var preparation
  private var accountID: Int64?
  private let onMutation: (CommunityPost) async -> Void
  private var currentUser: () async -> CommunityPost.Owner? = { nil }
  private var isCurrentSession: () -> Bool = { false }
  private let onUnauthorized: () -> Void
  private var generation = 0
  private var snapshots: [Int64: DiscussionSnapshot] = [:]
  @ObservationIgnored private var replyUpdateTask: Task<Void, Never>?
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
    let isCurrent: @Sendable () -> Bool = { profile.isCurrentSession(session) }
    accountID = session.accountID
    currentOwner = initialOwner ?? profile.cachedOwner(session)
    let owner = initialOwner
    currentUser = {
      if let owner { return owner }
      return try? await profile.loadOwner(session)
    }
    isCurrentSession = isCurrent
    replyComposer = makeReplyComposer(for: post)
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
      if isCurrentSession() { handleUnauthorized() }
    } catch CommunityError.rejected(let status) {
      mutationError = status == 404 ? .postDeleteUnavailable : .postDeleteRejected(status)
    } catch {
      mutationError = .postDeleteUncertain
    }
  }

  func restore() async { await replyComposer?.restore() }

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
      if isCurrentSession() { handleUnauthorized() }
    } catch is CancellationError {
    } catch {
      if isCurrentSession() { loadError = .postRepliesLoadError }
    }
  }

  func select(_ item: CommunityPost, ignoringDraft: String? = nil) {
    guard item.id != post.id else { return }
    replyUpdateTask?.cancel()
    let previous = replyComposer
    if previous?.isPublishing != true { previous?.stop() }
    Task { _ = await previous?.flushDraft() }
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
    resetSelection(ignoringDraft: ignoringDraft)
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
      if isCurrentSession() { handleUnauthorized() }
    } catch is CancellationError {
    } catch {
      if isCurrentSession() { pageError = .postRepliesLoadError }
    }
  }

  func expandEditor() {
    guard composer == nil, let replyComposer, !replyComposer.isPublishing else { return }
    composer = replyComposer
  }

  func reply(to item: CommunityPost) {
    guard composer == nil, replyComposer?.isPublishing != true else { return }
    if item.id == post.id { expandEditor() }
    else {
      let current = replyComposer
      Task { _ = await current?.flushDraft() }
      composer = makeReplyComposer(for: item)
    }
  }

  func saveDraft() async {
    _ = await replyComposer?.flushDraft()
    if let composer, composer !== replyComposer { _ = await composer.flushDraft() }
  }

  func stop() {
    generation += 1
    replyUpdateTask?.cancel()
    replyComposer?.stop()
    if let composer, composer !== replyComposer { composer.stop() }
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

  private func makeReplyComposer(for item: CommunityPost, ignoringDraft: String? = nil) -> CommunityComposerViewModel? {
    let originID = post.id
    return withDependencies(from: self) {
      let model = CommunityComposerViewModel(
        replyTo: item.descriptor, suppressDraft: { $0 == ignoringDraft },
        onUnauthorized: onUnauthorized,
        onPublished: { [weak self] descriptor, text, warning in
          self?.didPublishReply(descriptor, text: text, to: item, originID: originID, warning: warning)
        })
      return model.start() ? model : nil
    }
  }

  private func handleUnauthorized() {
    profileService.clearSession()
    onUnauthorized()
  }

  private func didPublishReply(
    _ descriptor: PostDescriptor, text: String, to target: CommunityPost,
    originID: Int64, warning: LocalizedStringResource?
  ) {
    guard isCurrentSession() else { return }
    let reply = CommunityPost.awaitingDetails(.init(
      descriptor: descriptor, text: text, owner: currentOwner, date: .now))
    cacheSentReply(reply, parentID: target.id)
    guard post.id == originID else { return }
    if target.id != post.id { select(target, ignoringDraft: text) }
    else { replyComposer = makeReplyComposer(for: post, ignoringDraft: text) }
    sendError = warning
    if !replies.contains(where: { $0.id == reply.id }), !pendingReplies.contains(where: { $0.id == reply.id }) {
      pendingReplies.append(reply)
      pendingRows.append(row(reply, reusing: []))
    }
    replyUpdateTask?.cancel()
    replyUpdateTask = Task { [weak self] in
      guard let self else { return }
      await refreshSentReplies(descriptor, parentID: target.id)
    }
  }

  private func refreshSentReplies(_ descriptor: PostDescriptor, parentID: Int64) async {
    await restore()
    let owner: CommunityPost.Owner?
    if let currentOwner { owner = currentOwner } else { owner = await currentUser() }
    guard isCurrentSession(), !Task.isCancelled, post.id == parentID else { return }
    let authored = pendingReplies.map { authoredReply($0, owner: owner) }
    let prepared = try? await preparation.prepare(authored, reusing: pendingRows)
    guard isCurrentSession(), !Task.isCancelled, post.id == parentID else { return }
    currentOwner = owner
    pendingReplies = pendingReplies.map { authoredReply($0, owner: owner) }
    if let prepared { pendingRows = pendingReplies.map { row($0, reusing: prepared) } }
    await load()
    guard isCurrentSession(), !Task.isCancelled, post.id == parentID else { return }
    snapshots[post.id] = snapshot()
    scrollToReplyID = descriptor.id
  }

  private func authoredReply(_ reply: CommunityPost, owner: CommunityPost.Owner?) -> CommunityPost {
    guard case let .awaitingDetails(value) = reply, value.owner == nil else { return reply }
    return .awaitingDetails(.init(
      descriptor: value.descriptor, text: value.text, edited: value.edited, owner: owner, date: value.date))
  }

  private func cacheSentReply(_ reply: CommunityPost, parentID: Int64) {
    guard var cached = snapshots[parentID] else { return }
    if !cached.replies.contains(where: { $0.id == reply.id }),
       !cached.pendingReplies.contains(where: { $0.id == reply.id }) {
      cached.pendingReplies.append(reply)
      cached.pendingRows.append(row(reply, reusing: []))
    }
    snapshots[parentID] = cached
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
    loaded = snapshot.pendingReplies.isEmpty
  }

  private func resetSelection(ignoringDraft: String?) {
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
    replyComposer = makeReplyComposer(for: post, ignoringDraft: ignoringDraft)
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
  var pendingReplies: [CommunityPost]
  var pendingRows: [CommunityFeedPost]
  let nextID: String?
}
