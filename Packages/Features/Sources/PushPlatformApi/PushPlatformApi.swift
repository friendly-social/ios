import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct PushPlatformApi: Sendable {
  public var configureFirebase: @Sendable (
    _ onToken: @escaping @Sendable (String) -> Void
  ) async -> Bool = { _ in false }
  public var registerForRemoteNotifications: @Sendable () async -> Void = {}
  public var openNotificationSettings: @Sendable () async -> Void = {}
  public var token: @Sendable (_ apnsToken: Data) async throws -> String
  public var deleteToken: @Sendable () async throws -> Void
}

extension PushPlatformApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
