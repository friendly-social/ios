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
  private(set) var replyGroups: [CommunityDiscussionReply] = []
  var replyRows: [CommunityFeedPost] { replyGroups.flatMap(\.rows) }
  var replies: [CommunityPost] { replyRows.map(\.post) }
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
  var destination: Destination?
  private(set) var replyComposer: CommunityComposerViewModel?
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
      destination = .edit(model)
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
    isLoadingMore = false
    isLoading = true
    loadError = nil
    pageError = nil
    defer { if generation == request { isLoading = false } }
    do {
      let details = try await fetchedDetails()
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      try await prepareDetails(details, generation: request)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      isLoading = false
      await markRead(details.post.descriptor, generation: request)
    } catch CommunityError.unauthorized {
      if isCurrentSession() { handleUnauthorized() }
    } catch is CancellationError {
    } catch {
      if generation == request, isCurrentSession(), !Task.isCancelled {
        loadError = .postRepliesLoadError
      }
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
      let preceding = precedingReplies(to: item)
      upstream = lineage + preceding.map(\.post)
      ancestorRows.append(selectedRow ?? row(post, reusing: []))
      ancestorRows.append(contentsOf: preceding)
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
    defer { if generation == request { isLoadingMore = false } }
    do {
      let page = try await service.replies(post.descriptor, cursor)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      let prepared = try await prepareReplies(page.data, reusing: replyRows)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      replyGroups = mergingReplies(prepared)
      pendingReplies.removeAll { pending in replies.contains { $0.id == pending.id } }
      pendingRows.removeAll { pending in replies.contains { $0.id == pending.id } }
      nextID = page.nextId
    } catch CommunityError.unauthorized {
      if isCurrentSession() { handleUnauthorized() }
    } catch is CancellationError {
    } catch {
      if generation == request, isCurrentSession(), !Task.isCancelled {
        pageError = .postRepliesLoadError
      }
    }
  }

  func expandEditor() {
    guard destination?.composer == nil, let replyComposer, !replyComposer.isPublishing else { return }
    destination = .compose(replyComposer)
  }

  func reply(to item: CommunityPost) {
    guard destination?.composer == nil, replyComposer?.isPublishing != true else { return }
    if item.id == post.id { expandEditor() }
    else {
      let current = replyComposer
      Task { _ = await current?.flushDraft() }
      destination = makeReplyComposer(for: item).map { .compose($0) }
    }
  }

  func saveDraft() async {
    _ = await replyComposer?.flushDraft()
    if let composer = destination?.composer, composer !== replyComposer { _ = await composer.flushDraft() }
  }

  func stop() {
    generation += 1
    replyUpdateTask?.cancel()
    replyComposer?.stop()
    if let composer = destination?.composer, composer !== replyComposer { composer.stop() }
    Task { await saveDraft() }
  }

}

extension CommunityPostDetailViewModel {
  enum Destination: Identifiable {
    case compose(CommunityComposerViewModel)
    case edit(CommunityEditViewModel)

    var id: ObjectIdentifier {
      switch self {
      case let .compose(model): ObjectIdentifier(model)
      case let .edit(model): ObjectIdentifier(model)
      }
    }
  }
}

extension CommunityPostDetailViewModel.Destination {
  var composer: CommunityComposerViewModel? {
    guard case let .compose(model) = self else { return nil }
    return model
  }

  var editor: CommunityEditViewModel? {
    guard case let .edit(model) = self else { return nil }
    return model
  }
}

private extension CommunityPostDetailViewModel {
  private func markRead(_ descriptor: PostDescriptor, generation request: Int) async {
    do {
      try await service.markRead(descriptor)
    } catch CommunityError.unauthorized {
      if generation == request, isCurrentSession(), !Task.isCancelled { handleUnauthorized() }
    } catch { }
  }

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
          !details.replies.data.contains(where: { replyPosts($0).contains { $0.id == focusedReply.id } }) else { return details }
    let target: CommunityPostDetails
    do { target = try await service.details(focusedReply) }
    catch CommunityError.rejected(404) { return details }
    guard target.upstream.last?.descriptor == details.post.descriptor else { return details }
    let replies = CommunityReplyPage(
      data: details.replies.data + [.single(target.post)], nextId: details.replies.nextId)
    return .init(post: details.post, upstream: details.upstream, replies: replies)
  }

  private func row(_ post: CommunityPost, reusing previous: [CommunityFeedPost]) -> CommunityFeedPost {
    if let cached = previous.first(where: { $0.id == post.id && $0.content.source == post.text }) {
      return CommunityFeedPost(post: post, content: cached.content)
    }
    return CommunityFeedPost(post: post, content: .init(source: post.text, excerpt: nil))
  }

  private func prepareDetails(_ details: CommunityPostDetails, generation request: Int) async throws {
    let previous = ancestorRows + replyRows + (selectedRow.map { [$0] } ?? [])
    let ancestors = try await preparation.prepare(details.upstream, reusing: previous)
    let preparedReplies = try await prepareReplies(details.replies.data, reusing: previous)
    let selected = await preparation.prepare(details.post)
    guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
    post = details.post
    selectedRow = selected
    upstream = details.upstream
    ancestorRows = ancestors
    replyGroups = preparedReplies
    nextID = details.replies.nextId
    pendingReplies.removeAll { pending in replies.contains { $0.id == pending.id } }
    pendingRows.removeAll { pending in replies.contains { $0.id == pending.id } }
    initialDetails = nil
    loaded = true
    snapshots[post.id] = snapshot()
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
    guard post.id == originID else {
      invalidateSnapshots()
      cacheSentReply(reply, parentID: target.id)
      return
    }
    if target.id != post.id { select(target, ignoringDraft: text) }
    if !replies.contains(where: { $0.id == reply.id }), !pendingReplies.contains(where: { $0.id == reply.id }) {
      pendingReplies.append(reply)
      pendingRows.append(row(reply, reusing: []))
    }
    snapshots[target.id] = snapshot()
    select(reply, ignoringDraft: text)
    invalidateSnapshots()
    selectedRow = row(reply, reusing: [])
    loaded = true
    sendError = warning
    scrollToReplyID = descriptor.id
    replyUpdateTask = Task { [weak self] in
      await self?.refreshSentReply(descriptor)
    }
  }

  private func refreshSentReply(_ descriptor: PostDescriptor) async {
    guard isCurrentSession(), !Task.isCancelled, post.descriptor == descriptor else { return }
    await restore()
    let owner: CommunityPost.Owner?
    if let currentOwner { owner = currentOwner } else { owner = await currentUser() }
    guard isCurrentSession(), !Task.isCancelled, post.descriptor == descriptor else { return }
    currentOwner = owner
    post = authoredReply(post, owner: owner)
    selectedRow = row(post, reusing: selectedRow.map { [$0] } ?? [])
    await load()
  }

  private func authoredReply(_ reply: CommunityPost, owner: CommunityPost.Owner?) -> CommunityPost {
    guard case let .awaitingDetails(value) = reply, value.owner == nil else { return reply }
    return .awaitingDetails(.init(
      descriptor: value.descriptor, text: value.text, edited: value.edited, owner: owner, date: value.date))
  }

  private func invalidateSnapshots() {
    snapshots = snapshots.mapValues { snapshot in
      var snapshot = snapshot
      snapshot.needsReload = true
      return snapshot
    }
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
      replyGroups: replyGroups, pendingReplies: pendingReplies,
      pendingRows: pendingRows, nextID: nextID)
  }

  private func restore(_ snapshot: DiscussionSnapshot) {
    post = snapshot.post
    selectedRow = snapshot.selectedRow
    upstream = snapshot.upstream
    ancestorRows = snapshot.ancestorRows
    replyGroups = snapshot.replyGroups
    pendingReplies = snapshot.pendingReplies
    pendingRows = snapshot.pendingRows
    nextID = snapshot.nextID
    loaded = snapshot.pendingReplies.isEmpty && !snapshot.needsReload
  }

  private func resetSelection(ignoringDraft: String?) {
    generation += 1
    isLoading = false
    isLoadingMore = false
    loaded = false
    loadError = nil
    pageError = nil
    replyGroups = []
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
    replyGroups = replyGroups.compactMap { group in
      CommunityDiscussionReply(rows: group.rows.map { item in
        row(item.id == updated.id ? updated : item.post, reusing: group.rows)
      })
    }
    pendingReplies = pendingReplies.map { $0.id == updated.id ? updated : $0 }
    await prepareUpdatedRows(generation: generation)
    if isCurrentSession() { await onMutation(updated) }
  }

  private func prepareUpdatedRows(generation request: Int) async {
    let ancestors = try? await preparation.prepare(upstream, reusing: ancestorRows)
    guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
    if let ancestors { ancestorRows = ancestors }
    let entries = replyGroups.map { CommunityReply.thread($0.rows.map(\.post)) }
    let groups = try? await prepareReplies(entries, reusing: replyRows)
    guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
    if let groups { replyGroups = groups }
    let pending = try? await preparation.prepare(pendingReplies, reusing: pendingRows)
    guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
    if let pending { pendingRows = pending }
  }

  private func replyPosts(_ reply: CommunityReply) -> [CommunityPost] {
    switch reply {
    case let .single(post): [post]
    case let .thread(posts): posts
    }
  }

  private func prepareReplies(
    _ replies: [CommunityReply], reusing previous: [CommunityFeedPost]
  ) async throws -> [CommunityDiscussionReply] {
    let posts = replies.flatMap(replyPosts)
    let rows = try await preparation.prepare(posts, reusing: previous)
    let byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    var seen: Set<Int64> = []
    return replies.compactMap { reply in
      let rows = replyPosts(reply).compactMap { post in
        seen.insert(post.id).inserted ? byID[post.id] : nil
      }
      return CommunityDiscussionReply(rows: rows)
    }
  }

  private func mergingReplies(_ additional: [CommunityDiscussionReply]) -> [CommunityDiscussionReply] {
    var result = replyGroups
    for group in additional {
      if let index = result.firstIndex(where: { $0.id == group.id }) {
        result[index] = group
      } else {
        result.append(group)
      }
    }
    return result
  }

  private func precedingReplies(to post: CommunityPost) -> [CommunityFeedPost] {
    for group in replyGroups {
      if let index = group.rows.firstIndex(where: { $0.id == post.id }) {
        return Array(group.rows.prefix(upTo: index))
      }
    }
    return []
  }
}

private struct DiscussionSnapshot {
  let post: CommunityPost
  let selectedRow: CommunityFeedPost?
  let upstream: [CommunityPost]
  let ancestorRows: [CommunityFeedPost]
  let replyGroups: [CommunityDiscussionReply]
  var replies: [CommunityPost] { replyGroups.flatMap(\.rows).map(\.post) }
  var pendingReplies: [CommunityPost]
  var pendingRows: [CommunityFeedPost]
  let nextID: String?
  var needsReload = false
}
