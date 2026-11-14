import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct PushRegistrationService: Sendable {
  public var authorizationStatus: @Sendable () async -> PushAuthorizationStatus = { .authorized }
  public var requestAuthorizationIfNeeded: @Sendable () async -> Void = {}
  public var openNotificationSettings: @Sendable () async -> Void = {}
  public var refresh: @Sendable () -> Void = {}
  public var receivedAPNsToken: @Sendable (_ token: Data) -> Void = { _ in }
}

public enum PushAuthorizationStatus: Sendable {
  case notDetermined
  case denied
  case authorized
}

extension PushRegistrationService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
