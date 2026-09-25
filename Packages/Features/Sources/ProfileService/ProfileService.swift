import DependenciesMacros
import Models

@DependencyClient
public struct ProfileService: Sendable {
  public var loadProfile: @Sendable (ProfileSelection) async throws -> ProfileInfo?
  public var declineFriend: @Sendable (UserId, UserAccessHash) async throws -> Void
  public var signOut: @Sendable () -> Void
}

public enum ProfileSelection {
  case current
  case other(id: UserId, accessHash: UserAccessHash)
}
