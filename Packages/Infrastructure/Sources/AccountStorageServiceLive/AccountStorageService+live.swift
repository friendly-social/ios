import AccountStorageService
import Dependencies

extension AccountStorageService {
  static func live() -> Self {
    let live = AccountStorageServiceLive()
    return .init(
      saveAuthorization: live.saveAuthorization,
      loadAuthorization: live.loadAuthorization,
      hasAuthorization: live.hasAuthorization,
      clearAuthorization: live.clearAuthorization,
      getHasFriend: live.getHasFriend,
      addFriend: live.addFriend,
      saveCommunityProfile: live.saveCommunityProfile,
      loadCommunityProfile: live.loadCommunityProfile
    )
  }
}

extension AccountStorageService: DependencyKey {
  public static var liveValue: Self { .live() }
}
