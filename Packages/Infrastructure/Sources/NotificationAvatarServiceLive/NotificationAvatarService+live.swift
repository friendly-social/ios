import Dependencies
import NotificationAvatarService

private extension NotificationAvatarService {
  static func live() -> Self {
    let service = NotificationAvatarServiceLive()
    return Self(load: service.load)
  }
}

extension NotificationAvatarService: DependencyKey {
  public static var liveValue: Self { .live() }
}
