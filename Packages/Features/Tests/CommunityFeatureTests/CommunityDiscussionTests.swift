@testable import CommunityApiLive
import CommunityDraftService
import CommunityDraftServiceLive
@testable import CommunityFeature
import CommunityService
@testable import CommunityServiceLive
import Foundation
import Testing

struct CommunityDiscussionTests {
  @Test func draftServiceNormalizesOnlyUnformattedMarkdown() {
    let service = CommunityDraftService.live()
    #expect(service.replyDraft("") == .plainText(""))
    #expect(service.replyDraft("просто текст") == .plainText("просто текст"))
    #expect(service.replyDraft("\\*звёздочки\\*") == .plainText("*звёздочки*"))
    #expect(service.replyDraft("**bold**") == .markdown("**bold**"))
    #expect(
      service.replyDraft("[link](https://example.com)") == .markdown("[link](https://example.com)"))
    #expect(
      service.replyDraft("![image](https://example.com/a.png)")
        == .markdown("![image](https://example.com/a.png)"))
  }

  @MainActor @Test func clearingFullScreenEditorRestoresPlainMiniComposer() {
    let model = makeModel()
    model.expandEditor()
    model.editor.loadSource("**bold**")
    model.editorChanged()
    model.editor.loadSource("")
    model.editorChanged()
    model.collapseEditor()
    #expect(model.draft == .plainText(""))
  }

  @MainActor @Test func plainFullScreenReplyReturnsToMiniComposer() {
    let model = makeModel()
    model.expandEditor()
    model.editor.loadSource("просто текст")
    model.editorChanged()
    model.collapseEditor()
    #expect(model.draft == .plainText("просто текст"))
  }

  @MainActor @Test func selectingReplyMovesItAboveRepliesOnTheSameDetail() async {
    let model = makeModel()
    await model.load()
    let selected = model.replies[0]
    model.select(selected)
    #expect(model.post.id == selected.id)
    #expect(model.upstream.map(\.id) == [1])
    #expect(model.replies.isEmpty)
  }

  @MainActor @Test func selectingAncestorTruncatesTheChain() async {
    let model = makeModel()
    await model.load()
    let first = model.replies[0]
    model.select(first)
    await model.load()
    let second = model.replies[0]
    model.select(second)
    model.select(model.upstream[0])
    #expect(model.post.id == 1)
    #expect(model.upstream.isEmpty)
    #expect(model.loaded)
    #expect(model.replies.map(\.id) == [2])
  }

  @MainActor @Test func replyingToAncestorOpensEditorWithoutSelectingAndThenTruncatesChain() async {
    let root = post(1)
    let child = post(2)
    let submission = DiscussionSubmission()
    var service = CommunityService()
    service.reply = { target, _ in
      await submission.record(targetID: target.id)
      return self.post(99).descriptor
    }
    service.details = { descriptor in
      if descriptor.id == child.id {
        return .init(post: child, upstream: [root], replies: .init(data: [], nextId: nil))
      }
      let replies = await submission.sent ? [self.post(3), self.post(99), self.post(4)] : [child]
      return .init(post: root, upstream: [], replies: .init(data: replies.map(CommunityReply.single), nextId: nil))
    }
    let model = makeDetailModel(
      post: root, service: service, preparation: .fixture,
      drafts: { _ in .init(load: { nil }, save: { _ in }, remove: {}) },
      isCurrentSession: { true }, onUnauthorized: {})
    await model.load()
    model.select(child)
    await model.load()
    model.reply(to: root)
    #expect(model.post.id == child.id && model.showsEditor)
    model.editor.loadSource("Reply")
    model.editorChanged()
    await model.send()
    #expect(await submission.targetID == root.id && model.post.id == root.id)
    #expect(model.upstream.isEmpty && model.replies.map(\.id) == [3, 99, 4])
    #expect(model.pendingReplies.isEmpty)
  }

  @MainActor @Test func replyingToListedReplyMovesItAboveServerOrderedReplies() async {
    let root = post(1)
    let target = post(2)
    let submission = DiscussionSubmission()
    var service = CommunityService()
    service.reply = { descriptor, _ in
      #expect(descriptor.id == target.id)
      await submission.record(targetID: descriptor.id)
      return self.post(99).descriptor
    }
    service.details = { descriptor in
      if descriptor.id == root.id {
        return .init(post: root, upstream: [], replies: .init(data: [.single(target)], nextId: nil))
      }
      let replies = await submission.sent ? [self.post(3), self.post(99), self.post(4)] : []
      return .init(post: target, upstream: [root], replies: .init(data: replies.map(CommunityReply.single), nextId: nil))
    }
    let model = makeDetailModel(
      post: root, service: service, preparation: .fixture,
      drafts: { _ in .init(load: { nil }, save: { _ in }, remove: {}) },
      isCurrentSession: { true }, onUnauthorized: {})
    await model.load()
    model.reply(to: target)
    #expect(model.post.id == root.id && model.showsEditor)
    model.editor.loadSource("Reply")
    model.editorChanged()
    await model.send()
    #expect(model.post.id == target.id && model.upstream.map(\.id) == [root.id])
    #expect(model.replies.map(\.id) == [3, 99, 4])
    #expect(model.scrollToReplyID == 99)
  }

  @MainActor @Test func pendingReplyUsesCurrentAuthorUntilServerDetailsArrive() async {
    let root = post(1)
    let owner = CommunityPost.Owner(
      id: 7, accessHash: "owner", nickname: "Alex",
      avatar: .init(id: 8, accessHash: "avatar"))
    var service = CommunityService()
    service.reply = { _, _ in self.post(99).descriptor }
    service.details = { _ in .init(post: root, upstream: [], replies: .init(data: [], nextId: nil)) }
    let model = makeDetailModel(
      post: root, service: service,
      preparation: .fixture,
      drafts: { _ in .init(load: { nil }, save: { _ in }, remove: {}) },
      currentUser: { owner }, isCurrentSession: { true }, onUnauthorized: {})
    model.plainText = "Reply"
    await model.send()
    #expect(model.pendingReplies.map(\.id) == [99])
    #expect(model.pendingReplies.first?.owner == owner)
    #expect(model.pendingReplies.first?.date != nil)
  }

  @Test func detailDecodesDirectRepliesWithoutFlatteningThread() throws {
    let payload = """
      {"post": {"id": 1, "accessHash": "root", "type": "plain", "text": "Root", "edited": false,
        "instant": "2026-09-23T10:30:00Z", "owner": {"id": 7, "accessHash": "owner", "nickname": "Alex"}},
       "upstream": [], "replies": {"data": [
         {"type": "single", "post": {"id": 2, "accessHash": "a", "type": "deleted", "instant": "2026-09-23T10:30:00Z"}},
         {"type": "thread", "thread": [
           {"id": 3, "accessHash": "b", "type": "deleted", "instant": "2026-09-23T10:30:00Z"},
           {"id": 4, "accessHash": "c", "type": "deleted", "instant": "2026-09-23T10:30:00Z"}
         ]}], "nextId": "cursor"}}
      """
    let details = try JSONDecoder().decode(CommunityPostDetailsResponse.self, from: Data(payload.utf8)).details
    #expect(details.replies.data.compactMap(\.directPost).map(\.id) == [2, 3])
    #expect(details.replies.nextId == "cursor")
    guard case let .thread(chain) = details.replies.data[1] else {
      Issue.record("Thread type was lost")
      return
    }
    #expect(chain.map(\.id) == [3, 4])
  }

  @MainActor @Test func detailLoadsFirstPageThenPaginatesWithDeduplication() async {
    let root = post(1)
    var service = CommunityService()
    service.details = { _ in
      .init(post: root, upstream: [], replies: .init(data: [.single(post(2))], nextId: "next"))
    }
    service.replies = { _, cursor in
      #expect(cursor == "next")
      return .init(data: [.single(post(2)), .thread([post(3), post(4)])], nextId: nil)
    }
    let model = makeDetailModel(
      post: root,
      service: service,
      preparation: .fixture,
      drafts: { _ in .init(load: { nil }, save: { _ in }, remove: {}) },
      isCurrentSession: { true }, onUnauthorized: {})
    await model.load()
    #expect(model.replies.map(\.id) == [2])
    await model.loadMore()
    #expect(model.replies.map(\.id) == [2, 3])
    #expect(model.nextID == nil)
  }
}

private actor DiscussionSubmission {
  private(set) var sent = false
  private(set) var targetID: Int64?

  func record(targetID: Int64) {
    self.targetID = targetID
    sent = true
  }
}

private extension CommunityDiscussionTests {
  @MainActor private func makeModel() -> CommunityPostDetailViewModel {
    var service = CommunityService()
    service.details = { descriptor in
      .init(post: self.post(descriptor.id),
            upstream: (1..<descriptor.id).map(self.post),
            replies: .init(data: [.single(self.post(descriptor.id + 1))], nextId: nil))
    }
    return makeDetailModel(
      post: post(1),
      service: service,
      preparation: .fixture,
      drafts: { _ in .init(load: { nil }, save: { _ in }, remove: {}) },
      isCurrentSession: { true }, onUnauthorized: {})
  }

  private func post(_ id: Int64) -> CommunityPost {
    .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "hash"), text: "Post"))
  }
}
