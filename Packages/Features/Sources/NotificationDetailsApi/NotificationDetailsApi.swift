import Dependencies
import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct NotificationDetailsApi: Sendable {
  public var content: @Sendable (
    _ id: Int64,
    _ session: NotificationSession
  ) async throws -> NotificationContent
}

public struct NotificationContent: Sendable {
  public let details: NotificationDetails
  public let target: NotificationTarget?

  public init(details: NotificationDetails, target: NotificationTarget?) {
    self.details = details
    self.target = target
  }
}

public enum NotificationTarget: Equatable, Sendable {
  case profile(id: UserId, accessHash: UserAccessHash)
  case reply(id: Int64, accessHash: String)
}

public enum NotificationDetails: Equatable, Sendable {
  case friendRequest(nickname: String, isMutual: Bool, senderImage: NotificationSenderImage? = nil)
  case reply(nickname: String, text: String, senderImage: NotificationSenderImage? = nil)
}

public struct NotificationSenderImage: Equatable, Sendable {
  public let senderID: Int64
  public let url: URL

  public init(senderID: Int64, url: URL) {
    self.senderID = senderID
    self.url = url
  }
}

public enum NotificationDetailsError: Error, Equatable {
  case unauthorized
  case unavailable
  case invalidResponse
}

extension NotificationDetailsApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
