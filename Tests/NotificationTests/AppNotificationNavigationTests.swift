import CommunityProfileService
import Dependencies
import Models
import NotificationDetailsApi
import NotificationOpeningService
import Synchronization
import Testing

@MainActor
struct AppNotificationNavigationTests {
  @Test func failureCanBeRetriedWithoutLosingTheNotificationID() async throws {
    let calls = Mutex(0)
    let result = try profile()
    let model = makeModel { selection, _ in
      #expect(selection.id == 42)
      try calls.withLock { count in
        count += 1
        if count == 1 { throw NotificationOpeningError.unavailable }
      }
      return result
    }
    await model.loadNotification(id: try #require(model.destination?.id))
    #expect(model.notification?.failed == true)
    #expect(model.notification?.content == nil)
    await model.loadNotification(id: try #require(model.destination?.id))
    #expect(model.notification?.failed == false)
    #expect(model.notification?.content != nil)
  }

  @Test func leavingTheScreenDropsALateResult() async throws {
    let gate = OpeningGate()
    let result = try profile()
    let model = makeModel { _, _ in
      await gate.wait()
      return result
    }
    let id = try #require(model.destination?.id)
    let load = Task { await model.loadNotification(id: id) }
    await gate.waitForRequest()
    #expect(model.notification?.isLoading == true)
    load.cancel()
    await gate.resume()
    await load.value
    #expect(model.notification?.content == nil)
    #expect(model.notification?.failed == false)
    #expect(model.notification?.isLoading == false)
  }

  @Test func changedAccountCannotShowThePreviousAccountsContent() async throws {
    let active = Mutex(true)
    let result = try profile()
    let model = makeModel(isCurrent: { active.withLock { $0 } }) { _, _ in
      active.withLock { $0 = false }
      return result
    }
    await model.loadNotification(id: try #require(model.destination?.id))
    #expect(model.notification?.content == nil)
    #expect(model.notification?.failed == false)
  }

  @Test func returningBackPreventsALateResultFromReopeningTheScreen() async throws {
    let gate = OpeningGate()
    let result = try profile()
    let model = makeModel { _, _ in
      await gate.wait()
      return result
    }
    let id = try #require(model.destination?.id)
    let load = Task { await model.loadNotification(id: id) }
    await gate.waitForRequest()
    model.destination = nil
    await gate.resume()
    await load.value
    #expect(model.destination == nil)
  }

  @Test func aNewTapCannotBeReplacedByThePreviousNotificationsLateResult() async throws {
    let gate = OpeningGate()
    let result = try profile()
    let model = makeModel { _, _ in
      await gate.wait()
      return result
    }
    let id = try #require(model.destination?.id)
    let load = Task { await model.loadNotification(id: id) }
    await gate.waitForRequest()
    model.showNotification(.init(id: 43))
    await gate.resume()
    await load.value
    #expect(model.notification?.selection.id == 43)
    #expect(model.notification?.content == nil)
    #expect(model.notification?.isLoading == false)
  }
}

private extension AppNotificationNavigationTests {
  private func profile() throws -> OpenedNotification {
    .profile(
      id: UserId(9),
      accessHash: try UserAccessHash(String(repeating: "h", count: UserAccessHash.length))
    )
  }

  private func makeModel(
    isCurrent: @escaping @Sendable () -> Bool = { true },
    open: @escaping @Sendable (
      NotificationSelection,
      CommunitySession
    ) async throws -> OpenedNotification
  ) -> AppViewModel {
    withDependencies {
      $0[NotificationOpeningService.self].currentSession = { Fixtures.session }
      $0[NotificationOpeningService.self].isCurrentSession = {
        $0 == Fixtures.session && isCurrent()
      }
      $0[NotificationOpeningService.self].open = open
    } operation: {
      let model = AppViewModel()
      model.destination = .notification(.init(selection: .init(id: 42)))
      return model
    }
  }
}

private actor OpeningGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var started = false
}

private extension OpeningGate {
  func wait() async {
    started = true
    await withCheckedContinuation { continuation = $0 }
  }

  func waitForRequest() async {
    while !started { await Task.yield() }
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private enum Fixtures {
  static let session = CommunitySession(
    accountID: 7,
    token: String(repeating: "t", count: Token.length),
    sessionID: "test-session"
  )
}

private extension AppViewModel {
  var notification: Notification? {
    guard case let .notification(notification) = destination else { return nil }
    return notification
  }
}
