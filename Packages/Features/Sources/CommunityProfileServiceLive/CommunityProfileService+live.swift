import CommunityProfileService
import Dependencies

extension CommunityProfileService {
  public static func live() -> Self {
    let live = CommunityProfileServiceLive()
    return .init(
      currentSession: { live.currentSession() },
      isCurrentSession: { live.isCurrentSession($0) },
      cachedOwner: { live.cachedOwner($0) },
      loadOwner: { try await live.loadOwner($0) },
      avatarURL: { live.avatarURL($0) },
      clearSession: { live.clearSession() }
    )
  }
}

extension CommunityProfileService: DependencyKey {
  public static var liveValue: Self { .live() }
}
