@testable import CommunityFeature
import CommunityService
import Testing

@MainActor
struct CommunityThreadTests {
  @Test func publishingToThreadTailInvalidatesAncestorSnapshot() async throws {
    let model = publishingModel(replies: [.thread([post(2), post(3), post(4)])])
    defer { model.stop() }
    await model.load()
    model.reply(to: post(4))
    let composer = try #require(model.destination?.composer)
    await composer.restore()
    composer.setPlainText("Continuation")
    await composer.publish()
    #expect(model.post.id == 99)
    #expect(model.upstream.map(\.id) == [1, 2, 3, 4])
    model.select(post(1))
    #expect(!model.loaded)
  }

  @Test func publicationAlreadyInParentPageDoesNotDuplicatePendingReply() async throws {
    let model = publishingModel(replies: [.single(post(99))])
    defer { model.stop() }
    await model.load()
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText("Already received by a concurrent refresh")
    await composer.publish()
    model.select(post(1))
    #expect(model.replies.map(\.id) == [99])
    #expect(model.pendingReplies.isEmpty)
  }

  @Test func consecutiveRepliesContinueFromTheLastPublishedPost() async throws {
    let submission = ThreadSubmission()
    var service = CommunityService()
    service.markRead = { _ in }
    service.reply = { target, _ in await submission.send(to: target) }
    service.details = { descriptor in
      .init(post: post(descriptor.id), upstream: (1..<descriptor.id).map(post),
            replies: .init(data: [], nextId: nil))
    }
    let model = makeDetailModel(post: post(1), service: service)
    await model.load()
    try await publish("First", in: model)
    #expect(model.post.id == 2)
    #expect(model.upstream.map(\.id) == [1])
    try await publish("Second", in: model)
    #expect(await submission.targets == [1, 2])
    #expect(model.post.id == 3)
    #expect(model.upstream.map(\.id) == [1, 2])
    #expect(model.pendingReplies.isEmpty)
    model.stop()
  }

  @Test func selectingThreadDescendantIncludesEveryPrecedingPost() async {
    let model = threadModel()
    await model.load()
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3, 4], [5]])
    model.select(post(4))
    #expect(model.post.id == 4)
    #expect(model.upstream.map(\.id) == [1, 2, 3])
    #expect(model.ancestorRows.map(\.id) == [1, 2, 3])
    model.select(post(1))
    #expect(model.loaded)
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3, 4], [5]])
    model.stop()
  }

  @Test func paginationUpdatesThreadWithoutDuplicatingItsRoot() async {
    let model = threadModel()
    await model.load()
    await model.loadMore()
    #expect(model.replies.map(\.id) == [2, 3, 4, 6, 5, 7, 8])
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3, 4, 6], [5], [7, 8]])
    #expect(model.nextID == nil)
    model.stop()
  }

  @Test func deletingThreadDescendantPreservesOtherPostsAndGrouping() async {
    let model = threadModel()
    await model.load()
    await model.delete(post(3))
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3, 4], [5]])
    guard case .deleted = model.replies[1] else {
      Issue.record("Deleted descendant was not updated")
      return
    }
    #expect(model.replies[2].text == "Post 4")
    model.stop()
  }
}

private extension CommunityThreadTests {
  private func publish(_ text: String, in model: CommunityPostDetailViewModel) async throws {
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText(text)
    await composer.publish()
    #expect(composer.published != nil)
  }

  private func threadModel() -> CommunityPostDetailViewModel {
    var service = CommunityService()
    service.markRead = { _ in }
    service.delete = { _ in }
    service.details = { _ in
      .init(post: post(1), upstream: [], replies: .init(
        data: [.thread([post(2), post(3), post(4)]), .single(post(5))], nextId: "next"))
    }
    service.replies = { _, _ in
      .init(data: [.thread([post(2), post(3), post(4), post(6)]), .thread([post(7), post(8)])],
            nextId: nil)
    }
    return makeDetailModel(post: post(1), service: service)
  }
}

private extension CommunityThreadTests {
  private func publishingModel(replies: [CommunityReply]) -> CommunityPostDetailViewModel {
    var service = CommunityService()
    service.markRead = { _ in }
    service.reply = { _, _ in post(99).descriptor }
    service.details = { descriptor in
      if descriptor.id == 99 { throw CommunityError.unavailable }
      return .init(post: post(1), upstream: [], replies: .init(data: replies, nextId: nil))
    }
    return makeDetailModel(post: post(1), service: service)
  }
}

private actor ThreadSubmission {
  private(set) var targets: [Int64] = []

  func send(to target: PostDescriptor) -> PostDescriptor {
    targets.append(target.id)
    return .init(id: Int64(targets.count + 1), accessHash: "hash")
  }
}

private func post(_ id: Int64) -> CommunityPost {
  .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "hash"), text: "Post \(id)"))
}
