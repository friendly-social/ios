@testable import ActivityFeature
import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Synchronization
import Testing

@MainActor
struct ActivityViewModelTests {
  @Test func listDeduplicatesPagesAndPreservesReadStatusOnRefresh() async {
    var service = ActivityService()
    service.list = { cursor, _ in
      .init(events: cursor == nil ? [event(1)] : [event(1), event(2)], nextID: cursor == nil ? "next" : nil)
    }
    let model = makeModel(service)
    await model.start()
    await model.loadMore()
    #expect(model.events.map(\.id) == [2, 1])
    model.openButtonTapped(event(1))
    #expect(model.discussion?.event.id == 1)
    model.didRead(1, session: .init(accountID: 7, token: "token", sessionID: "session"))
    #expect(model.events.first(where: { $0.id == 1 })?.isRead == true)
    await model.load()
    #expect(model.events.first?.isRead == true)
  }

  @Test func tappingNotificationNavigatesImmediatelyWithoutLoadingDiscussion() async {
    let calls = Mutex(0)
    var service = ActivityService()
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    service.openReply = { _, _ in
      calls.withLock { $0 += 1 }
      throw ActivityError.unavailable
    }
    let model = makeModel(service)
    await model.start()
    model.openButtonTapped(event(1))
    #expect(model.discussion?.event.id == 1)
    #expect(model.discussion?.session.accountID == 7)
    #expect(model.events.first?.isRead == false)
    #expect(calls.withLock { $0 } == 0)
  }

  @Test func staleSessionDoesNotNavigateOrAcceptReadCallback() async {
    let state = SessionState()
    var service = ActivityService()
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    let model = makeModel(service, current: { state.current })
    await model.start()
    state.expire()
    model.openButtonTapped(event(1))
    model.didRead(1, session: .init(accountID: 7, token: "token", sessionID: "session"))
    #expect(model.discussion == nil)
    #expect(model.events.first?.isRead == false)
  }

  @Test func listIsNotReloadedWhenReturningFromDiscussion() async {
    let ledger = ActivityLedger()
    var service = ActivityService()
    service.list = { _, _ in
      await ledger.recordList()
      return .init(events: [event(1)], nextID: nil)
    }
    let model = makeModel(service)
    await model.start()
    await model.start()
    #expect(await ledger.listCalls == 1)
  }

  @Test func oldPaginationFailureDoesNotPolluteRefreshedList() async {
    let gate = ActivityPageGate()
    var service = ActivityService()
    service.list = { cursor, _ in
      if cursor != nil { return try await gate.request() }
      return .init(events: [event(1)], nextID: "next")
    }
    let model = makeModel(service)
    await model.start()
    let oldPage = Task { await model.loadMore() }
    await gate.waitForRequest()
    await model.load()
    await gate.fail()
    await oldPage.value
    #expect(model.pageError == nil)
    #expect(model.nextID == "next")
    #expect(!model.isLoadingMore)
  }
}

private extension ActivityViewModelTests {
  private func makeModel(
    _ service: ActivityService, current: @escaping @Sendable () -> Bool = { true }
  ) -> ActivityViewModel {
    var profile = CommunityProfileService()
    profile.currentSession = { .init(accountID: 7, token: "token", sessionID: "session") }
    profile.isCurrentSession = { _ in current() }
    profile.clearSession = {}
    return withDependencies {
      $0[ActivityService.self] = service
      $0[CommunityProfileService.self] = profile
    } operation: { ActivityViewModel(onUnauthorized: {}) }
  }
}

private func event(_ id: Int64) -> ActivityEvent {
  let reply = CommunityPost.published(.init(
    descriptor: .init(id: id, accessHash: "hash"), text: "Reply",
    owner: .init(id: 8, accessHash: "user", nickname: "Author"), date: .now, edited: false))
  return .init(id: id, date: .init(timeIntervalSince1970: Double(id)), isRead: false, reply: reply)
}

private actor ActivityLedger {
  var listCalls = 0
  func recordList() { listCalls += 1 }
}

private final class SessionState: Sendable {
  private let active = Mutex(true)
  var current: Bool { active.withLock { $0 } }
  func expire() { active.withLock { $0 = false } }
}

private actor ActivityPageGate {
  private var completion: CheckedContinuation<ActivityPage, any Error>?
  private var started: CheckedContinuation<Void, Never>?

  func request() async throws -> ActivityPage {
    try await withCheckedThrowingContinuation {
      completion = $0
      started?.resume()
      started = nil
    }
  }

  func waitForRequest() async {
    if completion != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func fail() { completion?.resume(throwing: ActivityError.unavailable); completion = nil }
}
