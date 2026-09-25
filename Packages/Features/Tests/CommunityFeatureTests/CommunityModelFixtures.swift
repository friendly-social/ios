import CommunityDraftService
import CommunityDraftServiceLive
@testable import CommunityFeature
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation

@MainActor
func makeFeedModel(
  feedPreparation: CommunityFeedPreparationService = .fixture,
  service: CommunityService,
  drafts: CommunityDrafts,
  accountID: Int64 = 7,
  initialCurrentUser: CommunityPost.Owner? = nil,
  loadCurrentUser: @escaping () async throws -> CommunityPost.Owner? = { nil },
  replyDrafts: @escaping (PostDescriptor) -> CommunityDrafts = { _ in .empty },
  detailDrafts: @escaping (PostDescriptor) -> CommunityReplyDrafts = { _ in .empty },
  isCurrentSession: @escaping () -> Bool = { true },
  onUnauthorized: @escaping () -> Void = {}
) -> CommunityViewModel {
  withDependencies {
    $0[CommunityService.self] = service
    $0[CommunityFeedPreparationService.self] = feedPreparation
    $0[CommunityProfileService.self] = profile(
      accountID: accountID,
      cachedOwner: initialCurrentUser,
      loadOwner: loadCurrentUser,
      isCurrent: isCurrentSession)
    $0[CommunityDraftService.self] = draftService(
      post: drafts,
      reply: replyDrafts,
      detail: detailDrafts)
  } operation: {
    let model = CommunityViewModel(onUnauthorized: onUnauthorized)
    _ = model.start()
    return model
  }
}

@MainActor
func makeComposerModel(
  service: CommunityService,
  drafts: CommunityDrafts,
  isCurrentSession: @escaping () -> Bool = { true },
  onUnauthorized: @escaping () -> Void = {}
) -> CommunityComposerViewModel {
  withDependencies {
    $0[CommunityService.self] = service
    $0[CommunityProfileService.self] = profile(isCurrent: isCurrentSession)
    $0[CommunityDraftService.self] = draftService(post: drafts)
  } operation: {
    let model = CommunityComposerViewModel(onUnauthorized: onUnauthorized)
    _ = model.start()
    return model
  }
}

@MainActor
func makeEditModel(
  post: CommunityPost,
  service: CommunityService,
  isCurrentSession: @escaping () -> Bool = { true },
  onUnauthorized: @escaping () -> Void = {},
  onSaved: @escaping (CommunityPost) async -> Void = { _ in }
) -> CommunityEditViewModel {
  withDependencies {
    $0[CommunityService.self] = service
    $0[CommunityProfileService.self] = profile(isCurrent: isCurrentSession)
  } operation: {
    let model = CommunityEditViewModel(
      post: post,
      onUnauthorized: onUnauthorized,
      onSaved: onSaved)
    model.start()
    return model
  }
}

@MainActor
func makeDetailModel(
  post: CommunityPost,
  service: CommunityService,
  preparation: CommunityFeedPreparationService = .fixture,
  drafts: @escaping (PostDescriptor) -> CommunityReplyDrafts = { _ in .empty },
  currentUser: @escaping () async -> CommunityPost.Owner? = { nil },
  isCurrentSession: @escaping () -> Bool = { true },
  onUnauthorized: @escaping () -> Void = {},
  onMutation: @escaping (CommunityPost) async -> Void = { _ in }
) -> CommunityPostDetailViewModel {
  withDependencies {
    $0[CommunityService.self] = service
    $0[CommunityFeedPreparationService.self] = preparation
    $0[CommunityProfileService.self] = profile(
      loadOwner: currentUser,
      isCurrent: isCurrentSession)
    $0[CommunityDraftService.self] = draftService(detail: drafts)
  } operation: {
    let model = CommunityPostDetailViewModel(
      post: post,
      onUnauthorized: onUnauthorized,
      onMutation: onMutation)
    _ = model.start()
    return model
  }
}

private func profile(
  accountID: Int64 = 7,
  cachedOwner: CommunityPost.Owner? = nil,
  loadOwner: @escaping () async throws -> CommunityPost.Owner? = { nil },
  isCurrent: @escaping () -> Bool = { true }
) -> CommunityProfileService {
  let session = CommunitySession(accountID: accountID, token: "test", sessionID: "test")
  var result = CommunityProfileService()
  result.currentSession = { session }
  result.isCurrentSession = { _ in isCurrent() }
  result.cachedOwner = { _ in cachedOwner }
  result.loadOwner = { _ in
    guard let owner = try await loadOwner() else { throw CommunityError.unavailable }
    return owner
  }
  result.clearSession = {}
  return result
}

private func draftService(
  post: CommunityDrafts = .empty,
  reply: @escaping (PostDescriptor) -> CommunityDrafts = { _ in .empty },
  detail: @escaping (PostDescriptor) -> CommunityReplyDrafts = { _ in .empty }
) -> CommunityDraftService {
  var result = CommunityDraftService()
  let postFixture = MainActorDraftFixture(value: post)
  result.postDrafts = { _, _, _ in postFixture.value }
  result.replyDrafts = { descriptor, _, _, _ in reply(descriptor) }
  result.detailDrafts = { descriptor, _, _, _ in detail(descriptor) }
  result.replyDraft = CommunityDraftService.live().replyDraft
  return result
}

// These test draft closures are created and consumed only by main-actor ViewModels.
// Remove this wrapper when draft fixtures use Sendable closures.
private struct MainActorDraftFixture: @unchecked Sendable {
  let value: CommunityDrafts
}

private extension CommunityDraftHandle where Content == String {
  static var empty: Self { .init(load: { nil }, save: { _ in }, remove: {}) }
}

private extension CommunityDraftHandle where Content == CommunityReplyDraft {
  static var empty: Self { .init(load: { nil }, save: { _ in }, remove: {}) }
}
