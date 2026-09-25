public import AddFriendService
public import Dependencies

extension AddFriendService {
  public static func live() -> Self {
    let live = AddFriendServiceLive()
    return .init(
      add: { try await live.add($0) },
      hasPendingReconciliation: { live.hasPendingReconciliation(authorization: $0) },
      reconcile: { try await live.reconcile() },
      clearReconciliation: { live.clearReconciliation() })
  }
}

extension AddFriendService: DependencyKey {
  public static var liveValue: Self { .live() }
}
