@testable import ActivityFeature
import ActivityService
import CommunityProfileService
import CommunityService
import CustomDump
import Dependencies
import Foundation
import Synchronization
import Testing

@MainActor
struct ActivityViewModelTests {
  @Test func groupsNowAndEarlierTodayTogetherBeforeYesterdayAndOlder() async throws {
    let calendar = Calendar.current
    let now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_792_997_200))
      .addingTimeInterval(12 * 60 * 60)
    let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
    let older = try #require(calendar.date(byAdding: .day, value: -2, to: now))
    let dates = [now, now.addingTimeInterval(-3 * 60 * 60), yesterday, older]
    let content = event(1).content
    let events = dates.enumerated().map { index, date in
      ActivityEvent(id: Int64(index), date: date, isRead: false, content: content)
    }
    var service = ActivityService()
    service.list = { _, _ in .init(events: events, nextID: nil) }
    service.acknowledgeUnreads = { _ in }
    let model = withDependencies {
      $0.date.now = now
    } operation: { makeModel(service) }
    await model.start()
    expectNoDifference(model.events(in: .today).map(\.id), [0, 1])
    expectNoDifference(model.events(in: .yesterday).map(\.id), [2])
    expectNoDifference(model.events(in: .older).map(\.id), [3])
  }

  @Test func openingListAcknowledgesBadgeWithoutMarkingRowsRead() async {
    let calls = Mutex(0)
    var service = ActivityService()
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    service.acknowledgeUnreads = { session in
      expectNoDifference(session.accountID, 7)
      calls.withLock { $0 += 1 }
    }
    let model = makeModel(service)
    await model.start()
    expectNoDifference(calls.withLock { $0 }, 1)
    expectNoDifference(model.events.first?.isRead, false)
  }

  @Test func failedListDoesNotAcknowledgeBadge() async {
    let calls = Mutex(0)
    var service = ActivityService()
    service.list = { _, _ in throw ActivityError.unavailable }
    service.acknowledgeUnreads = { _ in calls.withLock { $0 += 1 } }
    let model = makeModel(service)
    await model.start()
    expectNoDifference(calls.withLock { $0 }, 0)
    #expect(model.error != nil)
  }

  @Test func failedAcknowledgementKeepsLoadedListUsable() async {
    var service = ActivityService()
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    service.acknowledgeUnreads = { _ in throw ActivityError.unavailable }
    let model = makeModel(service)
    await model.start()
    expectNoDifference(model.events.count, 1)
    #expect(model.error == nil)
    #expect(!model.isLoading)
  }

  @Test func listDeduplicatesPagesAndPreservesReadStatusOnRefresh() async {
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
    service.list = { cursor, _ in
      .init(events: cursor == nil ? [event(1)] : [event(1), event(2)], nextID: cursor == nil ? "next" : nil)
    }
    let model = makeModel(service)
    await model.start()
    await model.loadMore()
    #expect(model.events.map(\.id) == [2, 1])
    model.openButtonTapped(event(1))
    guard case let .discussion(destination) = model.destination else {
      Issue.record("Expected discussion destination")
      return
    }
    expectNoDifference(destination.event.id, 1)
    model.didRead(1, session: .init(accountID: 7, token: "token", sessionID: "session"))
    #expect(model.events.first(where: { $0.id == 1 })?.isRead == true)
    await model.load()
    #expect(model.events.first?.isRead == true)
  }

  @Test func tappingNotificationNavigatesImmediatelyWithoutLoadingDiscussion() async {
    let calls = Mutex(0)
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    service.openReply = { _, _ in
      calls.withLock { $0 += 1 }
      throw ActivityError.unavailable
    }
    let model = makeModel(service)
    await model.start()
    model.openButtonTapped(event(1))
    guard case let .discussion(destination) = model.destination else {
      Issue.record("Expected discussion destination")
      return
    }
    expectNoDifference(destination.event.id, 1)
    expectNoDifference(destination.session.accountID, 7)
    #expect(model.events.first?.isRead == false)
    #expect(calls.withLock { $0 } == 0)
  }

  @Test func staleSessionDoesNotNavigateOrAcceptReadCallback() async {
    let state = SessionState()
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
    service.list = { _, _ in .init(events: [event(1)], nextID: nil) }
    let model = makeModel(service, current: { state.current })
    await model.start()
    state.expire()
    model.openButtonTapped(event(1))
    model.didRead(1, session: .init(accountID: 7, token: "token", sessionID: "session"))
    #expect(model.destination == nil)
    #expect(model.events.first?.isRead == false)
  }

  @Test func listIsNotReloadedWhenReturningFromDiscussion() async {
    let ledger = ActivityLedger()
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
    service.list = { _, _ in
      await ledger.recordList()
      return .init(events: [event(1)], nextID: nil)
    }
    let model = makeModel(service)
    await model.start()
    await model.start()
    #expect(await ledger.listCalls == 1)
  }

  @Test(arguments: friendshipContents())
  func friendRequestOpensProfileAndMarksReadOnlyAfterOpening(content: ActivityEvent.Content) async throws {
    let calls = Mutex<[Int64]>([])
    let request = ActivityEvent(id: 42, date: .init(timeIntervalSince1970: 0), isRead: false, content: content)
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
    service.list = { _, _ in .init(events: [request], nextID: nil) }
    service.markRead = { id, _ in calls.withLock { $0.append(id) } }
    let model = makeModel(service)
    await model.start()
    model.openButtonTapped(request)
    guard case let .profile(destination) = model.destination else {
      Issue.record("Expected profile destination")
      return
    }
    expectNoDifference(destination.userID.int64, 8)
    expectNoDifference(calls.withLock { $0 }, [])
    await model.profileOpened(destination)
    expectNoDifference(calls.withLock { $0 }, [42])
    expectNoDifference(model.events.first?.isRead, true)
  }

  @Test func oldPaginationFailureDoesNotPolluteRefreshedList() async {
    let gate = ActivityPageGate()
    var service = ActivityService()
    service.acknowledgeUnreads = { _ in }
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

private func friendshipContents() -> [ActivityEvent.Content] {
  let user = CommunityPost.Owner(id: 8, accessHash: String(repeating: "a", count: 256), nickname: "Аня")
  return [.friendRequest(from: user), .friendRequestAccepted(from: user)]
}

private func event(_ id: Int64) -> ActivityEvent {
  let reply = CommunityPost.published(.init(
    descriptor: .init(id: id, accessHash: "hash"), text: "Reply",
    owner: .init(id: 8, accessHash: "user", nickname: "Author"), date: .now, edited: false))
  return .init(id: id, date: .init(timeIntervalSince1970: Double(id)), isRead: false, content: .reply(reply))
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
