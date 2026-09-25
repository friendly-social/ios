import AccountStorageService
import AccountSessionService
import AddFriendService
import Dependencies
import FriendAccessService
import Models

struct FriendAccessServiceLive: Sendable {
  @Dependency(AddFriendService.self) private var addFriendService
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(AccountSessionService.self) private var accountSession

  func initialAccess() throws -> FriendAccessState {
    guard try storage.hasAuthorization() else { return .signedOut }
    let authorization = try storage.loadAuthorization()
    if addFriendService.hasPendingReconciliation(authorization) {
      return .reconcile
    }
    return try storage.getHasFriend() ? .main : .addFriend
  }

  func hasAuthorization() throws -> Bool {
    try storage.hasAuthorization()
  }

  func hasFriendAccess() throws -> Bool {
    try storage.getHasFriend()
  }

  func completeEmailLogin() {
    try? storage.addFriend()
    addFriendService.clearReconciliation()
  }

  func clearPendingReconciliation() {
    addFriendService.clearReconciliation()
  }

  func invalidateAuthorization() {
    accountSession.clearAuthorization()
  }

  func addFriend(_ command: AddFriendCommand) async throws {
    do {
      try await addFriendService.add(command)
    } catch AddFriendService.AddError.alreadyProcessing {
      throw FriendAccessError.alreadyProcessing
    } catch AddFriendService.AddError.invalidInvite {
      throw FriendAccessError.invalidInvite
    } catch {
      throw FriendAccessError.retryable
    }
  }

  func reconcileFriendAccess() async throws -> Bool {
    try await addFriendService.reconcile()
  }
}
