import DependenciesMacros
import Models

@DependencyClient
public struct FriendAccessService: Sendable {
  public var initialAccess: @Sendable () throws -> FriendAccessState
  public var hasAuthorization: @Sendable () throws -> Bool
  public var hasFriendAccess: @Sendable () throws -> Bool
  public var completeEmailLogin: @Sendable () -> Void
  public var clearPendingReconciliation: @Sendable () -> Void
  public var invalidateAuthorization: @Sendable () -> Void
  public var addFriend: @Sendable (AddFriendCommand) async throws -> Void
  public var reconcileFriendAccess: @Sendable () async throws -> Bool
}

public enum FriendAccessState {
  case signedOut
  case reconcile
  case main
  case addFriend
}

public enum FriendAccessError: Error {
  case alreadyProcessing
  case invalidInvite
  case retryable
}
