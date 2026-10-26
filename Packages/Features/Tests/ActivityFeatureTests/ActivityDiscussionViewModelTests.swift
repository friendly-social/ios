import ActivityDiscussionFeature
import ActivityService
import CommunityProfileService
import CommunityService
import CustomDump
import Dependencies
import Foundation
import Synchronization
import Testing

@MainActor
struct ActivityDiscussionViewModelTests {
  @Test func newScreenLoadsDiscussionAndMarksNotificationRead() async {
    var didRead = false
    var service = ActivityService()
    service.openReply = { _, _ in discussion() }
    service.markRead = { _, _ in }
    let model = makeModel(service, onRead: { didRead = true })
    await model.load()
    #expect(model.discussion?.details.post.id == 10)
    #expect(model.error == nil)
    #expect(didRead)
  }

  @Test func indirectRepliesOpenCommonDenominatorAsThread() async throws {
    let post = try #require(event().post)
    let root = PostDescriptor(id: 20, accessHash: "root")
    let update = ActivityEvent(id: 42, date: .init(timeIntervalSince1970: 0), isRead: false,
                              content: .indirectReplies(post: post, commonDenominator: root))
    var service = ActivityService()
    service.openThread = { descriptor, _ in
      expectNoDifference(descriptor, root)
      return .init(details: discussion().details, replyID: nil)
    }
    service.markRead = { _, _ in }
    let model = makeModel(service, event: update)
    await model.load()
    #expect(model.discussion != nil)
    #expect(model.discussion?.replyID == nil)
    #expect(model.error == nil)
  }

  @Test func spinnerIsShownWhileDiscussionLoads() async {
    let gate = DiscussionGate()
    var service = ActivityService()
    service.openReply = { _, _ in await gate.request() }
    service.markRead = { _, _ in }
    let model = makeModel(service)
    let load = Task { await model.load() }
    await gate.waitForRequest()
    #expect(model.isLoading)
    #expect(model.discussion == nil)
    #expect(model.error == nil)
    await gate.resume()
    await load.value
    #expect(!model.isLoading)
    #expect(model.discussion != nil)
  }

  @Test func failedLoadShowsErrorOnDiscussionScreenAndCanRetry() async {
    let calls = Mutex(0)
    var didRead = false
    var service = ActivityService()
    service.openReply = { _, _ in
      let number = calls.withLock { $0 += 1; return $0 }
      if number == 1 { throw ActivityError.unavailable }
      return discussion()
    }
    service.markRead = { _, _ in }
    let model = makeModel(service, onRead: { didRead = true })
    await model.load()
    #expect(model.discussion == nil)
    #expect(model.error != nil)
    #expect(!didRead)
    await model.load()
    #expect(model.discussion != nil)
    #expect(model.error == nil)
    #expect(didRead)
  }

  @Test func failedReadDoesNotHideLoadedDiscussion() async {
    var didRead = false
    var service = ActivityService()
    service.openReply = { _, _ in discussion() }
    service.markRead = { _, _ in throw ActivityError.unavailable }
    let model = makeModel(service, onRead: { didRead = true })
    await model.load()
    #expect(model.discussion != nil)
    #expect(model.error == nil)
    #expect(!didRead)
  }

  @Test func backDuringLoadingDiscardsLateResultAndDoesNotMarkRead() async {
    let gate = DiscussionGate()
    var didRead = false
    var service = ActivityService()
    service.openReply = { _, _ in await gate.request() }
    service.markRead = { _, _ in Issue.record("Cancelled opening must not mark read") }
    let model = makeModel(service, onRead: { didRead = true })
    let load = Task { await model.load() }
    await gate.waitForRequest()
    load.cancel()
    await gate.resume()
    await load.value
    #expect(model.discussion == nil)
    #expect(model.error == nil)
    #expect(!didRead)
    #expect(!model.isLoading)
  }

  @Test func changedSessionDiscardsLateResultAndDoesNotMarkRead() async {
    let active = Mutex(true)
    var service = ActivityService()
    service.openReply = { _, _ in
      active.withLock { $0 = false }
      return discussion()
    }
    service.markRead = { _, _ in Issue.record("Stale session must not mark read") }
    let model = makeModel(service, current: { active.withLock { $0 } })
    await model.load()
    #expect(model.discussion == nil)
    #expect(model.error == nil)
  }

  @Test func backDuringRetryDiscardsLateResultAndDoesNotMarkRead() async {
    let gate = DiscussionGate()
    let calls = Mutex(0)
    var service = ActivityService()
    service.openReply = { _, _ in
      let number = calls.withLock { $0 += 1; return $0 }
      if number == 1 { throw ActivityError.unavailable }
      return await gate.request()
    }
    service.markRead = { _, _ in Issue.record("Cancelled retry must not mark read") }
    let model = makeModel(service)
    await model.load()
    #expect(model.error != nil)
    let retry = Task { await model.load() }
    await gate.waitForRequest()
    retry.cancel()
    await gate.resume()
    await retry.value
    #expect(model.discussion == nil)
    #expect(model.error == nil)
    #expect(!model.isLoading)
  }

  @Test func loadedDiscussionDoesNotReloadWhenViewAppearsAgain() async {
    let calls = Mutex(0)
    var service = ActivityService()
    service.openReply = { _, _ in
      calls.withLock { $0 += 1 }
      return discussion()
    }
    service.markRead = { _, _ in }
    let model = makeModel(service)
    await model.load()
    await model.load()
    #expect(calls.withLock { $0 } == 1)
  }
}

private extension ActivityDiscussionViewModelTests {
  private func makeModel(
    _ service: ActivityService, event: ActivityEvent = event(), current: @escaping @Sendable () -> Bool = { true },
    onRead: @escaping () -> Void = {}
  ) -> ActivityDiscussionViewModel {
    var profile = CommunityProfileService()
    profile.isCurrentSession = { _ in current() }
    return withDependencies {
      $0[ActivityService.self] = service
      $0[CommunityProfileService.self] = profile
    } operation: {
      ActivityDiscussionViewModel(
        event: event, session: .init(accountID: 7, token: "token", sessionID: "session"),
        onUnauthorized: {}, onRead: onRead)
    }
  }
}

private func event() -> ActivityEvent {
  let reply = CommunityPost.published(.init(
    descriptor: .init(id: 1, accessHash: "hash"), text: "Reply",
    owner: .init(id: 8, accessHash: "user", nickname: "Author"), date: .now, edited: false))
  return .init(id: 1, date: .now, isRead: false, content: .reply(reply))
}

private func discussion() -> ActivityDiscussion {
  let ours = CommunityPost.published(.init(
    descriptor: .init(id: 10, accessHash: "parent"), text: "Ours",
    owner: .init(id: 7, accessHash: "user", nickname: "Us"), date: .now, edited: false))
  return .init(details: .init(post: ours, upstream: [],
                             replies: .init(data: [.single(event().post!)], nextId: nil)), replyID: 1)
}

private actor DiscussionGate {
  private var completion: CheckedContinuation<ActivityDiscussion, Never>?
  private var started: CheckedContinuation<Void, Never>?

  func request() async -> ActivityDiscussion {
    await withCheckedContinuation {
      completion = $0
      started?.resume()
      started = nil
    }
  }

  func waitForRequest() async {
    if completion != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func resume() { completion?.resume(returning: discussion()); completion = nil }
}
