public import ProfileService
public import Dependencies

extension ProfileService {
  static func live() -> Self {
    let live = ProfileServiceLive()
    return .init(
      loadProfile: { try await live.loadProfile($0) },
      declineFriend: { try await live.declineFriend(id: $0, accessHash: $1) },
      signOut: { live.signOut() }
    )
  }
}

extension ProfileService: DependencyKey {
  public static var liveValue: Self { .live() }
}
