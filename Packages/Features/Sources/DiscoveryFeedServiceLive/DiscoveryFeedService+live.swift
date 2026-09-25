public import DiscoveryFeedService
public import Dependencies

extension DiscoveryFeedService {
  static func live() -> Self {
    let live = DiscoveryFeedServiceLive()
    return .init(
      loadCandidates: { try await live.loadCandidates() },
      requestFriend: { try await live.requestFriend(id: $0, accessHash: $1) },
      declineFriend: { try await live.declineFriend(id: $0, accessHash: $1) }
    )
  }
}

extension DiscoveryFeedService: DependencyKey {
  public static var liveValue: Self { .live() }
}
