@testable import CommunityFeature
import CommunityService
import CustomDump
import Foundation
import Testing

@MainActor
struct CommunityAuthorNavigationTests {
  @Test func feedAuthorOpensItsOwnProfileDestination() {
    let model = CommunityViewModel(onUnauthorized: {})
    let owner = owner()
    model.openAuthor(owner)
    guard case let .author(id, accessHash) = model.destination else {
      Issue.record("Expected a feed author destination")
      return
    }
    expectNoDifference(id.int64, owner.id)
    expectNoDifference(accessHash.string, owner.accessHash)
  }

  @Test func postAuthorKeepsTheParentPostDestination() {
    let model = CommunityViewModel(onUnauthorized: {})
    let owner = owner()
    let post = post(owner: owner)
    model.openDetails(.init(post: post, content: .init(source: post.text, document: nil)))
    guard case let .post(route) = model.destination else {
      Issue.record("Expected a post destination")
      return
    }
    route.model.openAuthor(owner)
    guard case let .author(id, accessHash) = route.model.navigationDestination else {
      Issue.record("Expected a local author destination")
      return
    }
    expectNoDifference(id.int64, owner.id)
    expectNoDifference(accessHash.string, owner.accessHash)
    expectNoDifference(model.destination, .post(route))
    #expect(route.model.sheetDestination == nil)
    route.model.navigationDestination = nil
    #expect(route.model.destination == nil)
    expectNoDifference(model.destination, .post(route))
  }

  @Test func invalidAuthorDoesNotNavigateOnEitherScreen() {
    let owner = CommunityPost.Owner(id: 42, accessHash: "invalid", nickname: "Anna")
    let feed = CommunityViewModel(onUnauthorized: {})
    let detail = CommunityPostDetailViewModel(post: post(owner: owner), onUnauthorized: {})
    feed.openAuthor(owner)
    detail.openAuthor(owner)
    #expect(feed.destination == nil)
    #expect(detail.destination == nil)
  }
}

private extension CommunityAuthorNavigationTests {
  private func owner() -> CommunityPost.Owner {
    .init(id: 42, accessHash: String(repeating: "a", count: 256), nickname: "Anna")
  }

  private func post(owner: CommunityPost.Owner) -> CommunityPost {
    .published(.init(
      descriptor: .init(id: 1, accessHash: "post"),
      text: "Test post",
      owner: owner,
      date: Date(timeIntervalSince1970: 0),
      edited: false
    ))
  }
}
