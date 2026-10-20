@testable import CommunityFeature
import CommunityService
import CustomDump
import Testing

@MainActor struct CommunityReplyComposerTests {
  @Test func compactAndExpandedReplyUseTheSameModelAndDocument() async throws {
    let model = makeDetailModel(post: post(1), service: .init())
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText("*literal*")
    model.expandEditor()
    #expect(model.composer === composer)
    expectNoDifference(composer.editor.markdown, "\\*literal\\*")
    composer.editor.loadSource("**Formatted reply**")
    model.composer = nil
    #expect(composer.plainText == nil)
    model.expandEditor()
    #expect(model.composer === composer)
    expectNoDifference(composer.editor.markdown, "**Formatted reply**")
    model.stop()
  }

  @Test func discardingReplyCancelsAutosaveAndClearsMiniComposer() async throws {
    var saved: [String] = []
    var removed: [Int64] = []
    let model = makeDetailModel(post: post(1), service: .init(), drafts: { target in
      .init(load: { nil }, save: { saved.append($0.content) }, remove: { removed.append(target.id) })
    })
    model.expandEditor()
    let composer = try #require(model.composer)
    await composer.restore()
    composer.editor.loadSource("**Reply draft**")
    composer.textChanged()
    #expect(await composer.discard())
    expectNoDifference(removed, [1])
    #expect(saved.isEmpty)
    #expect(model.replyComposer === composer)
    expectNoDifference(composer.plainText, "")
    #expect(composer.editor.markdown.isEmpty)
    model.stop()
  }

  @Test func discardingAncestorReplyKeepsCurrentPostDraft() async throws {
    var removed: [Int64] = []
    let model = makeDetailModel(post: post(2), service: .init(), drafts: { target in
      .init(load: { nil }, save: { _ in }, remove: { removed.append(target.id) })
    })
    let current = try #require(model.replyComposer)
    await current.restore()
    current.setPlainText("Current post draft")
    model.reply(to: post(1))
    let composer = try #require(model.composer)
    await composer.restore()
    #expect(composer !== current)
    composer.editor.loadSource("Ancestor reply")
    composer.textChanged()
    #expect(await composer.discard())
    expectNoDifference(removed, [1])
    expectNoDifference(model.post.id, 2)
    expectNoDifference(current.plainText, "Current post draft")
    model.stop()
  }

  @Test func failedDiscardKeepsEditorContentAndAllowsRetry() async throws {
    var attempts = 0
    let model = makeDetailModel(post: post(1), service: .init(), drafts: { _ in
      .init(load: { nil }, save: { _ in }, remove: {
        attempts += 1
        if attempts == 1 { throw CommunityError.unavailable }
      })
    })
    model.expandEditor()
    let composer = try #require(model.composer)
    await composer.restore()
    composer.editor.loadSource("Keep this reply")
    composer.textChanged()
    #expect(await !composer.discard())
    expectNoDifference(composer.editor.markdown, "Keep this reply")
    #expect(composer.draftError != nil)
    #expect(await composer.discard())
    #expect(composer.draftError == nil)
    expectNoDifference(attempts, 2)
    model.stop()
  }

  @Test func lateReplyDoesNotNavigateAwayFromAnotherSelectedPost() async throws {
    let submission = SuspendedReply()
    let root = post(1)
    let other = post(2)
    let reply = post(99)
    var service = CommunityService()
    service.reply = { _, _ in await submission.send() }
    service.details = { descriptor in
      let replies = await submission.sent ? [CommunityReply.single(reply)] : []
      return .init(post: descriptor.id == root.id ? root : other,
        upstream: [], replies: .init(data: replies, nextId: nil))
    }
    let model = makeDetailModel(post: root, service: service)
    await model.load()
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText("Reply to the original post")
    let request = Task { await composer.publish() }
    await submission.waitUntilStarted()
    model.select(other)
    await submission.finish()
    await request.value
    expectNoDifference(model.post.id, 2)
    #expect(model.pendingReplies.isEmpty && model.scrollToReplyID == nil)
    model.select(root)
    #expect(!model.loaded)
    expectNoDifference(model.pendingReplies.map(\.id), [99])
    await model.load()
    expectNoDifference(model.replies.map(\.id), [99])
    model.stop()
  }

  @Test func successfulPublicationDoesNotWaitForDiscussionRefresh() async throws {
    let root = post(1)
    let owner = SuspendedReplyOwner()
    var service = CommunityService()
    service.reply = { _, _ in .init(id: 99, accessHash: "reply") }
    service.details = { _ in .init(post: root, upstream: [], replies: .init(data: [], nextId: nil)) }
    let model = makeDetailModel(post: root, service: service, currentUser: owner.load)
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.setPlainText("Published reply")
    var finished = false
    let request = Task { await composer.publish(); finished = true }
    await owner.waitUntilStarted()
    for _ in 0..<Constants.maximumActorTurns {
      if finished { break }
      await Task.yield()
    }
    #expect(finished)
    owner.finish()
    await request.value
    model.stop()
  }
}

private extension CommunityReplyComposerTests {
  private func post(_ id: Int64) -> CommunityPost {
    .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "fixture"), text: "Post"))
  }
}

private actor SuspendedReply {
  private(set) var sent = false
  private var waiter: CheckedContinuation<Void, Never>?
  private var completion: CheckedContinuation<PostDescriptor, Never>?

  func send() async -> PostDescriptor {
    await withCheckedContinuation {
      completion = $0
      waiter?.resume()
      waiter = nil
    }
  }

  func waitUntilStarted() async {
    if completion != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func finish() {
    sent = true
    completion?.resume(returning: .init(id: 99, accessHash: "reply"))
    completion = nil
  }
}

@MainActor private final class SuspendedReplyOwner {
  private var waiter: CheckedContinuation<Void, Never>?
  private var completion: CheckedContinuation<CommunityPost.Owner?, Never>?

  func load() async -> CommunityPost.Owner? {
    await withCheckedContinuation {
      completion = $0
      waiter?.resume()
      waiter = nil
    }
  }

  func waitUntilStarted() async {
    if completion != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func finish() {
    completion?.resume(returning: nil)
    completion = nil
  }
}

private enum Constants {
  static let maximumActorTurns = 1000
}
