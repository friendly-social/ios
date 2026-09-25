import DependenciesMacros
import Models

@DependencyClient
public struct AddFriendService: Sendable {
  public var add: @Sendable (AddFriendCommand) async throws -> Void
  public var hasPendingReconciliation: @Sendable (Authorization) -> Bool = { _ in false }
  public var reconcile: @Sendable () async throws -> Bool
  public var clearReconciliation: @Sendable () -> Void = {}

  public enum AddError: Error {
    case alreadyProcessing
    case invalidInvite
    case retryable
  }

  public enum ReconciliationError: Error {
    case retryable
  }
}
