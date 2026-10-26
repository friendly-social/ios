import ActivityService
import CommunityDraftService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
public final class CommunityViewModel {
  enum DraftState { case unknown, empty, available }
  private(set) var draftState: DraftState = .unknown
  @ObservationIgnored @Dependency(CommunityDraftService.self) private var draftService
  private(set) var feedPosts: [CommunityFeedPost] = []
  public var posts: [CommunityPost] { feedPosts.map(\.post) }
  @ObservationIgnored @Dependency(CommunityFeedPreparationService.self) private var feedPreparation
  private(set) var hasNewActivity = false
  @ObservationIgnored @Dependency(ActivityService.self) private var activityService
  public private(set) var isLoading = false
  public private(set) var nextID: String?
  public private(set) var error: LocalizedStringResource?
  public var notice: LocalizedStringResource?
  var destination: Destination?
  public var composerTitle: LocalizedStringResource { destination?.composer?.title ?? .composerTitle }
  public private(set) var currentUser: CommunityPost.Owner?
  private var replyTarget: PostDescriptor?
  private var loadCurrentUser: (() async throws -> CommunityPost.Owner?)?
  public private(set) var deletingID: Int64?
  public var mutationError: LocalizedStringResource?
  private var accountID: Int64?
  @ObservationIgnored @Dependency(CommunityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profileService
  private var isCurrentSession: () -> Bool = { false }
  private var onUnauthorized: () -> Void
  private var refreshTask: Task<Void, Never>?
  private var deleteTask: Task<Void, Never>?
  private var loadMoreTask: Task<Void, Never>?
  private var pendingPosts: [CommunityPost] = []
  private var publishedDrafts: Set<String> = []
  private var generation = 0

  public func avatarURL(_ avatar: CommunityPost.Owner.Avatar) -> URL {
    profileService.avatarURL(avatar)
  }

  public init(onUnauthorized: @escaping () -> Void) {
    self.onUnauthorized = onUnauthorized
  }

  @discardableResult
  public func start() -> Bool {
    guard let session = profileService.currentSession() else { return false }
    let profile = profileService
    let isCurrent: @Sendable () -> Bool = { profile.isCurrentSession(session) }
    hasNewActivity = false
    accountID = session.accountID
    currentUser = profile.cachedOwner(session)
    loadCurrentUser = { try await profile.loadOwner(session) }
    isCurrentSession = isCurrent
    let callback = onUnauthorized
    onUnauthorized = {
      profile.clearSession()
      callback()
    }
    return true
  }

  func openActivity() {
    destination = .activity
  }

  func openDetails(_ item: CommunityFeedPost, focusReply: Bool = false) {
    guard navigationDestination == nil else { return }
    destination = .post(PostDetailRoute(
      descriptor: item.post.descriptor,
      model: makeDetails(for: item),
      focusReplyOnAppear: focusReply
    ))
  }

  func makeDetails(for item: CommunityFeedPost) -> CommunityPostDetailViewModel {
    withDependencies(from: self) {
      let details = CommunityPostDetailViewModel(
        post: item.post,
        selectedRow: item,
        currentOwner: currentUser,
        onUnauthorized: onUnauthorized,
        onMutation: { [weak self] updated in await self?.applyDetailMutation(updated) })
      return details
    }
  }

  private func applyDetailMutation(_ updated: CommunityPost) async {
    guard isCurrentSession() else { return }
    invalidateLoad()
    if case .deleted = updated {
      feedPosts.removeAll { $0.id == updated.id }
      pendingPosts.removeAll { $0.id == updated.id }
      return
    }
    guard feedPosts.contains(where: { $0.id == updated.id }) else { return }
    let prepared = await feedPreparation.prepare(updated)
    guard isCurrentSession() else { return }
    feedPosts = feedPosts.map { $0.id == updated.id ? prepared : $0 }
    pendingPosts = pendingPosts.map { $0.id == updated.id ? updated : $0 }
  }

  func refreshActivity() async {
    guard isCurrentSession(), !Task.isCancelled,
          let session = profileService.currentSession() else { return }
    do {
      let hasNew = try await activityService.hasNewUnreads(session)
      guard profileService.isCurrentSession(session), !Task.isCancelled else { return }
      hasNewActivity = hasNew
    } catch CommunityError.unauthorized {
      if profileService.isCurrentSession(session), !Task.isCancelled { onUnauthorized() }
    } catch { }
  }

  public func loadProfile() async {
    guard let loadCurrentUser, isCurrentSession(), !Task.isCancelled else { return }
    do {
      let user = try await loadCurrentUser()
      guard isCurrentSession(), !Task.isCancelled else { return }
      currentUser = user
    } catch CommunityError.unauthorized {
      guard isCurrentSession(), !Task.isCancelled else { return }
      onUnauthorized()
    } catch { /* Profile failure must not hide a usable feed. */  }
  }

  public func reply(to post: CommunityPost) {
    guard deletingID == nil, sheetDestination == nil, isCurrentSession() else { return }
    replyTarget = post.descriptor
    withDependencies(from: self) {
      let model = CommunityComposerViewModel(
        replyTo: post.descriptor, onUnauthorized: onUnauthorized,
        onPublished: { [weak self] in await self?.didPublish($0, text: $1, warning: $2) })
      if model.start() { destination = .compose(model) }
    }
  }

  public func compose() {
    guard deletingID == nil, sheetDestination == nil, isCurrentSession() else { return }
    replyTarget = nil
    withDependencies(from: self) {
      let model = CommunityComposerViewModel(
        suppressDraft: { [weak self] in self?.publishedDrafts.contains($0) == true },
        didSaveDraft: { [weak self] in self?.publishedDrafts.remove($0) },
        onUnauthorized: onUnauthorized,
        onPublished: { [weak self] in await self?.didPublish($0, text: $1, warning: $2) })
      if model.start() { destination = .compose(model) }
    }
  }

  public func canManage(_ post: CommunityPost) -> Bool {
    showsPostActions(for: post) && isCurrentSession()
  }

  func showsPostActions(for post: CommunityPost) -> Bool {
    guard let accountID else { return false }
    switch post {
    case let .published(post): return post.owner.id == accountID
    case .awaitingDetails: return true
    case .deleted: return false
    }
  }

  func observeDraft() async {
    guard let session = profileService.currentSession() else { return }
    let profile = profileService
    do {
      let updates = try await draftService.postDraftUpdates(session.accountID, session.sessionID)
      for await source in updates {
        guard !Task.isCancelled, profile.isCurrentSession(session) else { return }
        draftState = source == nil || source.map(publishedDrafts.contains) == true ? .empty : .available
      }
    } catch { }
  }

  public func editButtonTapped(_ post: CommunityPost) {
    guard canManage(post), deletingID == nil, sheetDestination == nil else { return }
    withDependencies(from: self) {
      let model = CommunityEditViewModel(
        post: post,
        onUnauthorized: onUnauthorized,
        onSaved: { [weak self] updated in await self?.applyEditedPost(updated) })
      model.start()
      destination = .edit(model)
    }
  }

  private func applyEditedPost(_ updated: CommunityPost) async {
    guard isCurrentSession() else { return }
    invalidateLoad()
    guard let text = updated.text else { return }
    let prepared = await feedPreparation.prepare(updated)
    guard isCurrentSession() else { return }
    invalidateLoad()
    feedPosts = feedPosts.map {
      $0.id == updated.id
        ? CommunityFeedPost(post: $0.post.replacingText(text), content: prepared.content) : $0
    }
    pendingPosts = pendingPosts.map {
      $0.id == updated.id ? $0.replacingText(text) : $0
    }
    notice = nil
  }

  public func deleteConfirmed(_ post: CommunityPost) async {
    guard canManage(post), deletingID == nil, sheetDestination == nil, !Task.isCancelled
    else { return }
    deletingID = post.id
    mutationError = nil
    defer { deletingID = nil }
    do {
      try await service.delete(post.id)
      guard isCurrentSession() else { return }
      invalidateLoad()
      feedPosts.removeAll { $0.id == post.id }
      pendingPosts.removeAll { $0.id == post.id }
      notice = nil
    } catch CommunityError.unauthorized {
      guard isCurrentSession() else { return }
      onUnauthorized()
    } catch CommunityError.rejected(let status) {
      guard isCurrentSession() else { return }
      mutationError =
        status == 404
        ? .postDeleteUnavailable
        : .postDeleteRejected(status)
    } catch {
      guard isCurrentSession() else { return }
      mutationError = .postDeleteUncertain
    }
  }

  public func deleteButtonTapped(_ post: CommunityPost) {
    guard deleteTask == nil else { return }
    deleteTask = Task {
      await deleteConfirmed(post)
      deleteTask = nil
    }
  }

  public func loadMoreButtonTapped() {
    guard loadMoreTask == nil else { return }
    loadMoreTask = Task {
      await load(more: true)
      loadMoreTask = nil
    }
  }

  public func load(more: Bool = false) async {
    guard isCurrentSession(), !Task.isCancelled else { return }
    if more && (isLoading || nextID == nil) { return }
    generation += 1
    let request = generation
    isLoading = true
    error = nil
    defer { if generation == request { isLoading = false } }
    do {
      let page = try await service.list(more ? nextID : nil)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      let received = Set(page.data.map(\.id))
      let remainingPending = pendingPosts.filter { !received.contains($0.id) }
      let candidates = more ? posts + page.data : remainingPending + page.data
      let visible = visiblePosts(in: candidates, page: page.data)
      let prepared = try await feedPreparation.prepare(visible, reusing: feedPosts)
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      pendingPosts = remainingPending
      feedPosts = prepared
      nextID = page.nextId
    } catch CommunityError.unauthorized {
      guard generation == request, isCurrentSession() else { return }
      onUnauthorized()
    } catch {
      guard generation == request, isCurrentSession(), !Task.isCancelled else { return }
      self.error = .feedLoadError
    }
  }

  public func didPublish(_ descriptor: PostDescriptor, text: String, warning: LocalizedStringResource?) async {
    guard isCurrentSession() else { return }
    if replyTarget != nil {
      replyTarget = nil
      if destination?.composer != nil { destination = nil }
      notice = warning
      refreshTask?.cancel()
      refreshTask = Task { [weak self] in await self?.load() }
      return
    }
    let post = CommunityPost.awaitingDetails(.init(
      descriptor: descriptor, text: text, owner: currentUser, date: .now))
    let prepared = await feedPreparation.prepare(post)
    guard isCurrentSession() else { return }
    invalidateLoad()
    if warning != nil { publishedDrafts.insert(text) }
    draftState = .empty
    pendingPosts.insert(post, at: 0)
    feedPosts.removeAll { $0.id == post.id }
    feedPosts.insert(prepared, at: 0)
    notice = warning
    if destination?.composer != nil { destination = nil }
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in await self?.load() }
  }

  public func stop() {
    refreshTask?.cancel()
    deleteTask?.cancel()
    loadMoreTask?.cancel()
    destination?.composer?.stop()
    generation += 1
    isLoading = false
  }
}

extension CommunityViewModel {
  enum Destination {
    case post(PostDetailRoute)
    case activity
    case compose(CommunityComposerViewModel)
    case edit(CommunityEditViewModel)
  }

  struct PostDetailRoute: Hashable {
    let model: CommunityPostDetailViewModel
    let focusReplyOnAppear: Bool
    private let descriptor: PostDescriptor

    init(
      descriptor: PostDescriptor,
      model: CommunityPostDetailViewModel,
      focusReplyOnAppear: Bool
    ) {
      self.model = model
      self.descriptor = descriptor
      self.focusReplyOnAppear = focusReplyOnAppear
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.descriptor == rhs.descriptor
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(descriptor)
    }
  }
}

extension CommunityViewModel {
  var navigationDestination: Destination? {
    get {
      switch destination {
      case .post, .activity: destination
      default: nil
      }
    }
    set {
      if let newValue { destination = newValue }
      else if navigationDestination != nil { destination = nil }
    }
  }

  var sheetDestination: Destination? {
    get {
      switch destination {
      case .compose, .edit: destination
      default: nil
      }
    }
    set {
      if let newValue { destination = newValue }
      else if sheetDestination != nil { destination = nil }
    }
  }
}

extension CommunityViewModel.Destination: Hashable, Identifiable {
  var id: Self { self }
}

extension CommunityViewModel.Destination {
  var composer: CommunityComposerViewModel? {
    guard case let .compose(model) = self else { return nil }
    return model
  }

  var editor: CommunityEditViewModel? {
    guard case let .edit(model) = self else { return nil }
    return model
  }
}

private extension CommunityViewModel {
  private func visiblePosts(
    in candidates: [CommunityPost], page: [CommunityPost]
  ) -> [CommunityPost] {
    let deletedIDs = Set(
      page.compactMap { post -> Int64? in
        if case .deleted = post { return post.id }
        return nil
      })
    var seen: Set<Int64> = []
    return candidates.filter {
      if case .deleted = $0 { return false }
      return !deletedIDs.contains($0.id) && seen.insert($0.id).inserted
    }
  }

  private func invalidateLoad() {
    refreshTask?.cancel()
    generation += 1
    isLoading = false
    error = nil
  }
}
