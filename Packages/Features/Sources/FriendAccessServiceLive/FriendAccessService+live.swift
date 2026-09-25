public import FriendAccessService
public import Dependencies

extension FriendAccessService {
  static func live() -> Self {
    let live = FriendAccessServiceLive()
    return .init(
      initialAccess: { try live.initialAccess() },
      hasAuthorization: { try live.hasAuthorization() },
      hasFriendAccess: { try live.hasFriendAccess() },
      completeEmailLogin: { live.completeEmailLogin() },
      clearPendingReconciliation: { live.clearPendingReconciliation() },
      invalidateAuthorization: { live.invalidateAuthorization() },
      addFriend: { try await live.addFriend($0) },
      reconcileFriendAccess: { try await live.reconcileFriendAccess() }
    )
  }
}

extension FriendAccessService: DependencyKey {
  public static var liveValue: Self { .live() }
}
