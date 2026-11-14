import ActivityService
import CommunityProfileService
import Dependencies
import DependenciesMacros
import Models
import NotificationDetailsApi

@DependencyClient
public struct NotificationOpeningService: Sendable {
  public var currentSession: @Sendable () -> CommunitySession? = { nil }
  public var isCurrentSession: @Sendable (_ session: CommunitySession) -> Bool = { _ in false }
  public var open: @Sendable (
    _ selection: NotificationSelection,
    _ session: CommunitySession
  ) async throws -> OpenedNotification
}

public enum OpenedNotification: Sendable {
  case profile(id: UserId, accessHash: UserAccessHash)
  case discussion(ActivityDiscussion)
}

public enum NotificationOpeningError: Error {
  case unavailable
  case unauthorized
}

extension NotificationOpeningService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
