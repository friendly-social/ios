import CommunityDraftService
@testable import CommunityFeature
import CommunityService
import Testing

@MainActor
struct CommunityPostTranslationEligibilityTests {
  @Test func feedAndDiscussionExcludeOwnPostsFromTranslation() {
    let feed = makeFeedModel(service: CommunityService(), drafts: emptyDrafts)
    let own = post(ownerID: 7)
    let other = post(ownerID: 8)
    let discussion = makeDetailModel(post: other, service: CommunityService())
    #expect(!feed.canTranslate(own))
    #expect(!discussion.canTranslate(own))
    #expect(feed.canTranslate(other))
    #expect(discussion.canTranslate(other))
  }

  @Test func newlyPublishedPostsWithoutAnAuthorHaveNoTranslation() {
    let pending = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 1, accessHash: "fixture"), text: "My newly published post"))
    let feed = makeFeedModel(service: CommunityService(), drafts: emptyDrafts)
    let discussion = makeDetailModel(post: pending, service: CommunityService())
    #expect(!feed.canTranslate(pending))
    #expect(!discussion.canTranslate(pending))
  }

  @Test func deletionRemovesTranslationEligibility() {
    let deleted = CommunityPost.deleted(.init(
      descriptor: .init(id: 1, accessHash: "fixture"), date: .now))
    let feed = makeFeedModel(service: CommunityService(), drafts: emptyDrafts)
    let discussion = makeDetailModel(post: deleted, service: CommunityService())
    #expect(!feed.canTranslate(deleted))
    #expect(!discussion.canTranslate(deleted))
  }
}

private extension CommunityPostTranslationEligibilityTests {
  private var emptyDrafts: CommunityDrafts {
    .init(load: { nil }, save: { _ in }, remove: {})
  }

  private func post(ownerID: Int64) -> CommunityPost {
    .published(.init(
      descriptor: .init(id: ownerID, accessHash: "fixture"), text: "A post for translation",
      owner: .init(id: ownerID, accessHash: "fixture", nickname: "Author"),
      date: .now, edited: false))
  }
}
