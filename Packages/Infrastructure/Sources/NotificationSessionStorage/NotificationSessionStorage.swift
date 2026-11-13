import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct NotificationSessionStorage: Sendable {
  public var save: @Sendable (_ session: NotificationSession) throws -> Void
  public var load: @Sendable () throws -> NotificationSession? = { nil }
  public var remove: @Sendable () throws -> Void
}

extension NotificationSessionStorage: TestDependencyKey {
  public static var testValue: Self { .init() }
}
