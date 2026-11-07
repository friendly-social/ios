import CommunityMarkdownService
public import Dependencies
public import ProfileService

private extension ProfileService {
  private static func live() -> Self {
    let live = ProfileServiceLive()
    return .init(
      prepareDescription: { await MarkdownDocument.prepare(source: $0) },
      loadProfile: { try await live.loadProfile($0) },
      loadFriends: { try await live.loadFriends() },
      requestFriend: { try await live.requestFriend(id: $0, accessHash: $1) },
      declineFriend: { try await live.declineFriend(id: $0, accessHash: $1) },
      signOut: { live.signOut() }
    )
  }
}

extension ProfileService: DependencyKey {
  public static var liveValue: Self { .live() }
}
