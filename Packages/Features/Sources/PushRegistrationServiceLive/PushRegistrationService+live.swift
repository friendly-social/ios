import Dependencies
import PushRegistrationService

private extension PushRegistrationService {
  static func live() -> Self {
    let service = PushRegistrationServiceLive()
    return Self(
      authorizationStatus: { await service.authorizationStatus() },
      requestAuthorizationIfNeeded: { await service.requestAuthorizationIfNeeded() },
      openNotificationSettings: { await service.openNotificationSettings() },
      refresh: { Task { await service.refresh() } },
      receivedAPNsToken: { token in Task { await service.receiveAPNsToken(token) } }
    )
  }
}

extension PushRegistrationService: DependencyKey {
  public static var liveValue: Self { .live() }
}
