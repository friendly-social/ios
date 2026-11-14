import AccountStorageService
import Dependencies

private extension AccountStorageService {
  static func live() -> Self {
    let live = AccountStorageServiceLive()
    return .init(
      saveAuthorization: live.saveAuthorization,
      loadAuthorization: live.loadAuthorization,
      hasAuthorization: live.hasAuthorization,
      clearAuthorization: live.clearAuthorization,
      shareNotificationSession: live.shareNotificationSession,
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
