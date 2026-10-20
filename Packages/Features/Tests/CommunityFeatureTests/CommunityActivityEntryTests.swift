@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import CustomDump
import Foundation
import Synchronization
import Testing

@MainActor
struct CommunityActivityEntryTests {
  @Test func loadedDiscussionMarksParentRead() async {
    let reads = Mutex<[PostDescriptor]>([])
    var service = CommunityService()
    service.markRead = { descriptor in reads.withLock { $0.append(descriptor) } }
    let model = makeDetailModel(post: post(2), service: service, initialDetails: details(post(2)))
    await model.load()
    expectNoDifference(reads.withLock { $0 }, [post(2).descriptor])
    #expect(model.loaded)
    #expect(model.loadError == nil)
  }

  @Test func failedDiscussionDoesNotMarkAnythingRead() async {
    let reads = Mutex(0)
    var service = CommunityService()
    service.markRead = { _ in }
    service.details = { _ in throw CommunityError.unavailable }
    service.markRead = { _ in reads.withLock { $0 += 1 } }
    let model = makeDetailModel(post: post(2), service: service)
    await model.load()
    expectNoDifference(reads.withLock { $0 }, 0)
    #expect(model.loadError != nil)
  }

  @Test func failedReadDoesNotHideLoadedDiscussion() async {
    var service = CommunityService()
    service.markRead = { _ in throw CommunityError.unavailable }
    let model = makeDetailModel(post: post(2), service: service, initialDetails: details(post(2)))
    await model.load()
    #expect(model.loaded)
    #expect(model.loadError == nil)
  }

  @Test func initialActivityDetailsKeepOurMessageAboveReceivedReply() async {
    let initial = details(post(2), upstream: [post(1)], replies: [post(3)])
    var service = CommunityService()
    service.markRead = { _ in }
    let model = makeDetailModel(post: post(2), service: service, initialDetails: initial)
    await model.load()
    #expect(model.loaded)
    #expect(model.post.id == 2)
    #expect(model.upstream.map(\.id) == [1])
    #expect(model.replies.map(\.id) == [3])
  }

  @Test func selectingReplyWhileInitialPreparationRunsDoesNotRestoreOriginalParent() async {
    let gate = PreparationGate()
    let reads = Mutex<[PostDescriptor]>([])
    var preparation = CommunityFeedPreparationService()
    preparation.prepareExcerpt = { _ in await gate.prepare() }
    var service = CommunityService()
    service.markRead = { descriptor in reads.withLock { $0.append(descriptor) } }
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
    expectNoDifference(reads.withLock { $0 }, [post(3).descriptor])
  }

  @Test func refreshKeepsReceivedReplyWhenParentPageOmitsIt() async {
    let reply = post(30)
    var service = CommunityService()
    service.markRead = { _ in }
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
    service.markRead = { _ in }
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
