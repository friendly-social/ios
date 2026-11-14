import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Models
import NotificationDetailsApi
import NotificationOpeningService

struct NotificationOpeningServiceLive: Sendable {
  @Dependency(ActivityService.self) private var activity
  @Dependency(CommunityProfileService.self) private var profile
  @Dependency(NotificationDetailsApi.self) private var notifications

  func open(
    selection: NotificationSelection,
    session: CommunitySession
  ) async throws -> OpenedNotification {
    try validate(session)
    do {
      let target = try await target(for: selection, session: session)
      try validate(session)
      let result = try await resolve(target, session: session)
      try validate(session)
      return result
    } catch {
      try validate(session)
      if error as? NotificationDetailsError == .unauthorized
        || error as? CommunityError == .unauthorized {
        profile.clearSession()
        throw NotificationOpeningError.unauthorized
      }
      throw NotificationOpeningError.unavailable
    }
  }
}

private extension NotificationOpeningServiceLive {
  private func target(
    for selection: NotificationSelection,
    session: CommunitySession
  ) async throws -> NotificationTarget {
    if let target = selection.context?.target(
      notificationID: selection.id,
      accountID: session.accountID
    ) {
      return target
    }
    let authorization = NotificationSession(
      userID: UserId(session.accountID),
      token: try Token(session.token)
    )
    let content = try await notifications.content(id: selection.id, session: authorization)
    guard let target = content.target else { throw NotificationDetailsError.invalidResponse }
    return target
  }

  private func resolve(
    _ target: NotificationTarget,
    session: CommunitySession
  ) async throws -> OpenedNotification {
    switch target {
    case let .profile(id, accessHash): return .profile(id: id, accessHash: accessHash)
    case let .reply(id, accessHash):
      let descriptor = PostDescriptor(id: id, accessHash: accessHash)
      return .discussion(try await activity.openReply(descriptor, session))
    }
  }

  private func validate(_ session: CommunitySession) throws {
    try Task.checkCancellation()
    guard profile.isCurrentSession(session) else { throw CancellationError() }
  }
}
