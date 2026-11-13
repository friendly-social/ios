import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PushTokenRegistrationService: Sendable {
  public var upload: @Sendable (
    _ firebaseToken: String,
    _ authorization: Authorization
  ) async throws -> Void
  public var reset: @Sendable () async -> Void = {}
}

extension PushTokenRegistrationService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
