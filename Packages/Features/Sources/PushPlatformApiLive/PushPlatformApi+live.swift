import Dependencies
import PushPlatformApi

private extension PushPlatformApi {
  static func live() -> Self {
    let api = PushPlatformApiLive()
    return Self(
      configureFirebase: { await api.configureFirebase(onToken: $0) },
      registerForRemoteNotifications: { await api.registerForRemoteNotifications() },
      openNotificationSettings: { await api.openNotificationSettings() },
      token: { try await api.token(apnsToken: $0) },
      deleteToken: { try await api.deleteToken() }
    )
  }
}

extension PushPlatformApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
