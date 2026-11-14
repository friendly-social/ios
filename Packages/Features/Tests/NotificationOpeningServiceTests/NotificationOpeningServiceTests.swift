import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Models
import NotificationDetailsApi
import NotificationOpeningService
import NotificationOpeningServiceLive
import Synchronization
import Testing

struct NotificationOpeningServiceTests {
  @Test func reusesTheExtensionsTargetWithoutFetchingNotificationDetailsAgain() async throws {
    let context = NotificationContext(notificationID: 42, accountID: 7, target: try profileTarget())
    let encoded = try JSONEncoder().encode(context)
    let restored = try JSONDecoder().decode(NotificationContext.self, from: encoded)
    #expect(!String(decoding: encoded, as: UTF8.self).contains(Fixtures.session.token))
    let service = makeService { _, _ in
      Issue.record("A valid extension context must not reload notification details")
      throw NotificationDetailsError.unavailable
    }
    let content = try await service.open(
      selection: .init(id: 42, context: restored),
      session: Fixtures.session
    )
    guard case let .profile(id, _) = content else {
      Issue.record("Expected a profile")
      return
    }
    #expect(id == UserId(9))
  }

  @Test(arguments: [false, true])
  func contextForAnotherAccountOrNotificationFallsBackToTheAPI(otherAccount: Bool) async throws {
    let context = NotificationContext(
      notificationID: otherAccount ? 42 : 43,
      accountID: otherAccount ? 8 : 7,
      target: .reply(id: 99, accessHash: "cached")
    )
    let calls = Mutex(0)
    let target = try profileTarget()
    let service = makeService { _, _ in
      calls.withLock { $0 += 1 }
      return target
    }
    let content = try await service.open(
      selection: .init(id: 42, context: context),
      session: Fixtures.session
    )
    guard case .profile = content else {
      Issue.record("Expected the API target")
      return
    }
    #expect(calls.withLock { $0 } == 1)
  }

  @Test func opensProfileUsingAuthorizedNotificationDetails() async throws {
    let target = try profileTarget()
    let service = makeService { id, authorization in
      #expect(id == 42)
      #expect(authorization.userID.int64 == Fixtures.session.accountID)
      #expect(authorization.token.string == Fixtures.session.token)
      return target
    }
    let content = try await service.open(selection: .init(id: 42), session: Fixtures.session)
    guard case let .profile(id, accessHash) = content else {
      Issue.record("Expected a profile")
      return
    }
    #expect(id == UserId(9))
    #expect(accessHash.string == String(repeating: "h", count: UserAccessHash.length))
  }

  @Test func resolvesTheExactReplyThroughTheExistingDiscussionService() async throws {
    var activity = ActivityService()
    activity.openReply = { descriptor, authorization in
      #expect(descriptor == PostDescriptor(id: 12, accessHash: "reply"))
      #expect(authorization == Fixtures.session)
      return Fixtures.discussion()
    }
    let service = withDependencies {
      $0[ActivityService.self] = activity
    } operation: {
      makeService { _, _ in .reply(id: 12, accessHash: "reply") }
    }
    let content = try await service.open(selection: .init(id: 42), session: Fixtures.session)
    guard case let .discussion(result) = content else {
      Issue.record("Expected a discussion")
      return
    }
    #expect(result.replyID == 12)
    #expect(result.details.post.id == 10)
  }

  @Test func aSessionChangeDiscardsTheResolvedTarget() async throws {
    let active = Mutex(true)
    let target = try profileTarget()
    let service = makeService(isCurrent: { active.withLock { $0 } }) { _, _ in
      active.withLock { $0 = false }
      return target
    }
    await #expect(throws: CancellationError.self) {
      try await service.open(selection: .init(id: 42), session: Fixtures.session)
    }
  }

  @Test func expiredAuthorizationClearsOnlyTheCurrentSession() async {
    let cleared = Mutex(false)
    let service = makeService(clearSession: { cleared.withLock { $0 = true } }) { _, _ in
      throw NotificationDetailsError.unauthorized
    }
    await #expect(throws: NotificationOpeningError.unauthorized) {
      try await service.open(selection: .init(id: 42), session: Fixtures.session)
    }
    #expect(cleared.withLock { $0 })
  }

  @Test func staleUnauthorizedResponseCannotSignOutAnotherAccount() async {
    let active = Mutex(true)
    let service = makeService(isCurrent: { active.withLock { $0 } }) { _, _ in
      active.withLock { $0 = false }
      throw NotificationDetailsError.unauthorized
    }
    await #expect(throws: CancellationError.self) {
      try await service.open(selection: .init(id: 42), session: Fixtures.session)
    }
  }

  @Test func unavailableNotificationDoesNotClearAuthorization() async {
    let service = makeService { _, _ in throw NotificationDetailsError.unavailable }
    await #expect(throws: NotificationOpeningError.unavailable) {
      try await service.open(selection: .init(id: 42), session: Fixtures.session)
    }
  }
}

private extension NotificationOpeningServiceTests {
  private func profileTarget() throws -> NotificationTarget {
    .profile(
      id: UserId(9),
      accessHash: try UserAccessHash(String(repeating: "h", count: UserAccessHash.length))
    )
  }

  private func makeService(
    isCurrent: @escaping @Sendable () -> Bool = { true },
    clearSession: @escaping @Sendable () -> Void = { Issue.record("Unexpected sign out") },
    target: @escaping @Sendable (Int64, NotificationSession) async throws -> NotificationTarget
  ) -> NotificationOpeningService {
    withDependencies {
      $0[CommunityProfileService.self].currentSession = { Fixtures.session }
      $0[CommunityProfileService.self].isCurrentSession = { $0 == Fixtures.session && isCurrent() }
      $0[CommunityProfileService.self].clearSession = clearSession
      $0[NotificationDetailsApi.self].content = { id, session in
        NotificationContent(
          details: .friendRequest(nickname: "Kai", isMutual: false),
          target: try await target(id, session)
        )
      }
    } operation: { NotificationOpeningService.liveValue }
  }
}

private enum Fixtures {
  static let session = CommunitySession(
    accountID: 7,
    token: String(repeating: "t", count: Token.length),
    sessionID: "test-session"
  )
}

private extension Fixtures {
  static func discussion() -> ActivityDiscussion {
    let post = CommunityPost.deleted(
      .init(descriptor: .init(id: 10, accessHash: "root"), date: .distantPast)
    )
    let details = CommunityPostDetails(
      post: post,
      upstream: [],
      replies: .init(data: [], nextId: nil)
    )
    return ActivityDiscussion(details: details, replyID: 12)
  }
}
