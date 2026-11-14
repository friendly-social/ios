import Dependencies
import DependenciesMacros
import UserNotifications

@DependencyClient
public struct NotificationEnrichmentService: Sendable {
  public var content: @Sendable (
    _ request: UNNotificationRequest
  ) async -> UNNotificationContent? = { _ in nil }
}

extension NotificationEnrichmentService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
