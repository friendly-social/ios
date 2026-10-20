import ActivityService
import DependenciesMacros

@DependencyClient
public struct ActivityApi: Sendable {
  public var list: @Sendable (String?, ActivityCredentials) async throws -> ActivityPage
  public var hasNewUnreads: @Sendable (ActivityCredentials) async throws -> Bool
  public var acknowledgeUnreads: @Sendable (ActivityCredentials) async throws -> Void
  public var markRead: @Sendable (Int64, ActivityCredentials) async throws -> Void
}

public struct ActivityCredentials: Sendable {
  public let accountID: Int64
  public let token: String

  public init(accountID: Int64, token: String) {
    self.accountID = accountID
    self.token = token
  }
}
