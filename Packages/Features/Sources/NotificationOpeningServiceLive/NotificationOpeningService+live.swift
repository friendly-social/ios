import CommunityProfileService
import Dependencies
import NotificationOpeningService

private extension NotificationOpeningService {
  static func live() -> Self {
    @Dependency(CommunityProfileService.self) var profile
    let service = NotificationOpeningServiceLive()
    return Self(
      currentSession: profile.currentSession,
      isCurrentSession: profile.isCurrentSession,
      open: service.open
    )
  }
}

extension NotificationOpeningService: DependencyKey {
  public static var liveValue: Self { .live() }
}
