import CommunityApi
import CommunityDraftService
@testable import CommunityApiLive
@testable import CommunityFeature
import CommunityService
@testable import CommunityServiceLive
import Foundation
import Testing

struct CommunityFeedRedesignTests {
  @MainActor @Test func feedUsesInjectedPreparation() async {
    let post = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 1, accessHash: "post"), text: "Injected"))
    let preparation = CommunityFeedPreparationService { source in
      #expect(source == "Injected")
      return nil
    }
    let model = makeFeedModel(
      feedPreparation: preparation,
      service: makeService(list: { _ in
        .init(data: [post], nextId: nil)
      }), drafts: .init(load: { nil }, save: { _ in }, remove: {}))
    await model.load()
    #expect(model.feedPosts.first?.content.source == "Injected")
    #expect(model.feedPosts.first?.content.excerpt == nil)
  }

  @Test func preparationReusesUnchangedContentAndRebuildsEditedPost() async throws {
    let service = CommunityFeedPreparationService.fixture
    let first = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 1, accessHash: "first"), text: "**First**"))
    let second = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 2, accessHash: "second"), text: "Second"))
    let original = try await service.prepare([first], reusing: [])
    let next = try await service.prepare([first, second], reusing: original)
    #expect(next.map(\.id) == [1, 2])
    #expect(next[0].content === original[0].content)
    #expect(next.allSatisfy { $0.content.excerpt != nil })
    let edited = try await service.prepare([first.replacingText("Changed"), second], reusing: next)
    #expect(edited[0].content !== next[0].content)
    #expect(edited[0].content.source == "Changed")
    #expect(edited[1].content === next[1].content)
  }

  @Test func preparationDoesNotReuseUnparsedReply() async throws {
    let service = CommunityFeedPreparationService.fixture
    let reply = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 3, accessHash: "reply"), text: "**Bold**"))
    let unparsed = CommunityFeedPost(
      post: reply, content: .init(source: reply.text, excerpt: nil))

    let prepared = try await service.prepare([reply], reusing: [unparsed])

    #expect(prepared[0].content !== unparsed.content)
    #expect(prepared[0].content.excerpt != nil)
  }

  @MainActor @Test func loadedAndPublishedPostsAlreadyHavePreparedContent() async throws {
    let first = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 1, accessHash: "first"), text: "**First**"))
    let second = CommunityPost.awaitingDetails(.init(
      descriptor: .init(id: 2, accessHash: "second"), text: "Second"))
    let model = makeFeedModel(feedPreparation: .fixture, service: makeService(
      list: { cursor in
        cursor == nil ? .init(data: [first], nextId: "next") : .init(data: [second], nextId: nil)
      }
    ), drafts: .init(load: { nil }, save: { _ in }, remove: {}))
    await model.load()
    let content = try #require(model.feedPosts.first?.content)
    #expect(content.excerpt != nil)
    await model.load(more: true)
    #expect(model.feedPosts.count == 2)
    #expect(model.feedPosts[0].content === content)
    #expect(model.feedPosts[1].content.excerpt != nil)
    await model.didPublish(.init(id: 3, accessHash: "third"), text: "Published", warning: nil)
    model.stop()
    #expect(model.feedPosts.first?.content.source == "Published")
    #expect(model.feedPosts.first?.content.excerpt != nil)
  }

  @Test func cancelledPreparationDoesNotReturnAPartialPage() async {
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await CommunityFeedPreparationService.fixture.prepare([
        .awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "first"), text: "Text"))
      ], reusing: [])
    }
    do {
      _ = try await task.value
      Issue.record("Cancelled preparation must not publish a partial page")
    } catch is CancellationError {
    } catch {
      Issue.record(error)
    }
  }

  @MainActor @Test func deletedPostsAreHiddenWithoutLosingPagination() async {
    let deleted = CommunityPost.deleted(.init(descriptor: .init(id: 1, accessHash: "hash"), date: .distantPast))
    let model = makeFeedModel(feedPreparation: .fixture, service: makeService(list: { _ in
      .init(data: [deleted], nextId: "next")
    }), drafts: .init(load: { nil }, save: { _ in }, remove: {}))
    await model.load()
    #expect(model.posts.isEmpty)
    #expect(model.nextID == "next")
  }

  @MainActor @Test func laterPageTombstoneRemovesPreviouslyLoadedPost() async {
    let descriptor = PostDescriptor(id: 1, accessHash: "hash")
    let visible = CommunityPost.published(.init(descriptor: descriptor, text: "Text", owner: .init(id: 7, accessHash: "owner", nickname: "Alex"), date: .distantPast, edited: false))
    let model = makeFeedModel(feedPreparation: .fixture, service: makeService(list: { cursor in
      cursor == nil
        ? .init(data: [visible], nextId: "next")
        : .init(data: [.deleted(.init(descriptor: descriptor, date: .distantPast))], nextId: nil)
    }), drafts: .init(load: { nil }, save: { _ in }, remove: {}))
    await model.load()
    #expect(model.posts.count == 1)
    await model.load(more: true)
    #expect(model.posts.isEmpty)
  }

  @Test(arguments: ["plain", "deleted"])
  func decodesReplyParticipants(type: String) throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "id": 1, "accessHash": "post", "type": type, "text": "Post",
      "edited": false, "instant": "2026-09-23T10:30:00Z",
      "owner": ["id": 2, "accessHash": "owner", "nickname": "Author"],
      "replyPreviews": [["id": 3, "accessHash": "participant", "nickname": "Reader",
        "avatar": ["id": 4, "accessHash": "avatar"]]],
    ])
    let post = try JSONDecoder().decode(CommunityPostResponse.self, from: data).post
    #expect(post.replyPreviews == [.init(id: 3, accessHash: "participant", nickname: "Reader", avatar: .init(id: 4, accessHash: "avatar"))])
    #expect(post.replacingText("Changed").replyPreviews == post.replyPreviews)
  }

  @Test func replyRequestIncludesParentAndExactMarkdown() async throws {
    let client = makeCommunityApi { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/community")
      let bytes = try #require(request.httpBody)
      let body = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      #expect(body["text"] as? String == "**Reply**")
      let parent = try #require(body["replyTo"] as? [String: Any])
      #expect(parent["id"] as? Int == 1)
      #expect(parent["accessHash"] as? String == "parent")
      return (Data(#"{"id":2,"accessHash":"reply"}"#.utf8), try makeHTTPResponse(for: request, statusCode: 200))
    }
    let result = try await client.publish("**Reply**", replyTo: .init(id: 1, accessHash: "parent"), credentials: .init(accountID: 7, token: "test"))
    #expect(result == .init(id: 2, accessHash: "reply"))
  }

  @MainActor @Test func replyUsesIsolatedDraftAndDoesNotInsertRootPost() async throws {
    let parent = CommunityPost.published(.init(descriptor: .init(id: 1, accessHash: "parent"), text: "Post", owner: .init(id: 7, accessHash: "owner", nickname: "Alex"), date: .distantPast, edited: false))
    let submission = ReplySubmission()
    var rootDraft = "Root draft"
    var replyDraft: String? = "Reply draft"
    var service = makeService(list: { _ in .init(data: [parent], nextId: nil) })
    service.publish = { _ in Issue.record("Root publication must not be used"); throw CommunityError.unavailable }
    service.reply = { descriptor, text in
      await submission.record(descriptor: descriptor, text: text)
      return .init(id: 2, accessHash: "reply")
    }
    let model = makeFeedModel(feedPreparation: .fixture, service: service, drafts: .init(load: { rootDraft }, save: { rootDraft = $0 }, remove: { rootDraft = "" }), replyDrafts: { descriptor in
      #expect(descriptor == parent.descriptor)
      return .init(load: { replyDraft }, save: { replyDraft = $0 }, remove: { replyDraft = nil })
    })
    await model.load()
    let newPostTitle = model.composerTitle
    model.reply(to: parent)
    #expect(model.composerTitle != newPostTitle)
    try await publishRestoredReply(in: model)
    #expect(await submission.descriptor == parent.descriptor)
    #expect(await submission.text == "Reply draft")
    #expect(rootDraft == "Root draft")
    #expect(replyDraft == nil)
    #expect(model.posts == [parent])
    #expect(model.composer == nil)
    model.compose()
    #expect(model.composerTitle == newPostTitle)
    model.stop()
  }

  @MainActor @Test func expiredSessionCannotLoadProfileOrOpenComposer() async {
    let drafts = CommunityDrafts(load: { nil }, save: { _ in }, remove: {})
    let model = makeFeedModel(feedPreparation: .fixture, service: makeService(list: { _ in .init(data: [], nextId: nil) }), drafts: drafts, loadCurrentUser: {
      Issue.record("Expired session must not request a profile")
      return nil
    }, isCurrentSession: { false })
    await model.loadProfile()
    model.compose()
    model.reply(to: .awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "hash"), text: "Post")))
    #expect(model.currentUser == nil)
    #expect(model.composer == nil)
  }

  @MainActor @Test func cachedProfileShowsBeforeRefreshAndUpdatesFromServer() async {
    let cached = CommunityPost.Owner(id: 7, accessHash: "owner", nickname: "Cached")
    let fresh = CommunityPost.Owner(id: 7, accessHash: "owner", nickname: "Fresh")
    let model = makeFeedModel(
      feedPreparation: .fixture,
      service: makeService(list: { _ in .init(data: [], nextId: nil) }),
      drafts: .init(load: { nil }, save: { _ in }, remove: {}),
      initialCurrentUser: cached,
      loadCurrentUser: { fresh })
    #expect(model.currentUser == cached)
    await model.loadProfile()
    #expect(model.currentUser == fresh)
  }
}

private actor ReplySubmission {
  private(set) var descriptor: PostDescriptor?
  private(set) var text: String?

  func record(descriptor: PostDescriptor, text: String) {
    self.descriptor = descriptor
    self.text = text
  }
}

private extension CommunityFeedRedesignTests {
  private func makeService(
    list: @escaping @Sendable (String?) async throws -> CommunityPage
  ) -> CommunityService {
    var service = CommunityService()
    service.publish = { _ in throw CommunityError.unavailable }
    service.list = list
    return service
  }

  @MainActor
  private func publishRestoredReply(in model: CommunityViewModel) async throws {
    let composer = try #require(model.composer)
    await composer.restore()
    #expect(composer.editor.markdown == "Reply draft")
    await composer.publish()
    let published = try #require(composer.published)
    await model.didPublish(published, text: composer.editor.markdown, warning: nil)
  }
}
