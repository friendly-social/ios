import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct NotificationAvatarService: Sendable {
  public var load: @Sendable (_ url: URL) async throws -> Data
}

public enum NotificationAvatarError: Error {
  case unavailable
}

extension NotificationAvatarService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
