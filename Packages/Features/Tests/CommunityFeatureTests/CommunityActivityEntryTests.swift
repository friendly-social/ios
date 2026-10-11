@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import Foundation
import Testing

@MainActor
struct CommunityActivityEntryTests {
  @Test func initialActivityDetailsKeepOurMessageAboveReceivedReply() async {
    let initial = details(post(2), upstream: [post(1)], replies: [post(3)])
    let model = makeDetailModel(post: post(2), service: .init(), initialDetails: initial)
    await model.load()
    #expect(model.loaded)
    #expect(model.post.id == 2)
    #expect(model.upstream.map(\.id) == [1])
    #expect(model.replies.map(\.id) == [3])
  }

  @Test func selectingReplyWhileInitialPreparationRunsDoesNotRestoreOriginalParent() async {
    let gate = PreparationGate()
    var preparation = CommunityFeedPreparationService()
    preparation.prepareExcerpt = { _ in await gate.prepare() }
    var service = CommunityService()
    service.details = { descriptor in details(post(descriptor.id), upstream: [post(1), post(2)]) }
    let initial = details(post(2), upstream: [post(1)], replies: [post(3)])
    let model = makeDetailModel(post: post(2), service: service,
                                initialDetails: initial, preparation: preparation)
    let firstLoad = Task { await model.load() }
    await gate.waitForRequest()
    model.select(post(3))
    await model.load()
    #expect(model.post.id == 3)
    await gate.resume()
    await firstLoad.value
    #expect(model.post.id == 3)
    #expect(model.upstream.map(\.id) == [1, 2])
  }

  @Test func refreshKeepsReceivedReplyWhenParentPageOmitsIt() async {
    let reply = post(30)
    var service = CommunityService()
    service.details = { descriptor in
      descriptor.id == reply.id ? details(reply, upstream: [post(1), post(2)])
        : details(post(2), upstream: [post(1)], replies: [post(3)])
    }
    let initial = details(post(2), upstream: [post(1)], replies: [post(3), reply])
    let model = makeDetailModel(post: post(2), service: service,
                                initialDetails: initial, focusedReply: reply.descriptor)
    await model.load()
    await model.load()
    #expect(model.post.id == 2)
    #expect(model.replies.map(\.id) == [3, 30])
  }

  @Test func deletedReceivedReplyDoesNotBlockRefreshingParent() async {
    let reply = post(30)
    var service = CommunityService()
    service.details = { descriptor in
      if descriptor.id == reply.id { throw CommunityError.rejected(404) }
      return details(post(2), upstream: [post(1)], replies: [post(3)])
    }
    let initial = details(post(2), upstream: [post(1)], replies: [post(3), reply])
    let model = makeDetailModel(post: post(2), service: service,
                                initialDetails: initial, focusedReply: reply.descriptor)
    await model.load()
    await model.load()
    #expect(model.loadError == nil)
    #expect(model.post.id == 2)
    #expect(model.replies.map(\.id) == [3])
  }
}

private func post(_ id: Int64) -> CommunityPost {
  .published(.init(descriptor: .init(id: id, accessHash: "hash"), text: "Post \(id)",
                   owner: .init(id: 7, accessHash: "user", nickname: "Us"),
                   date: .init(timeIntervalSince1970: Double(id)), edited: false))
}

private func details(
  _ post: CommunityPost, upstream: [CommunityPost] = [], replies: [CommunityPost] = []
) -> CommunityPostDetails {
  .init(post: post, upstream: upstream, replies: .init(data: replies.map(CommunityReply.single), nextId: nil))
}

private actor PreparationGate {
  private var calls = 0
  private var completion: CheckedContinuation<MarkdownExcerpt?, Never>?
  private var started: CheckedContinuation<Void, Never>?

  func prepare() async -> MarkdownExcerpt? {
    calls += 1
    if calls > 1 { return nil }
    return await withCheckedContinuation {
      completion = $0
      started?.resume()
      started = nil
    }
  }

  func waitForRequest() async {
    if completion != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func resume() { completion?.resume(returning: nil); completion = nil }
}
