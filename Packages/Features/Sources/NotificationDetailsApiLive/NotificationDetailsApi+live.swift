import Dependencies
import NotificationDetailsApi

private extension NotificationDetailsApi {
  static func live() -> Self {
    let api = NotificationDetailsApiLive()
    return Self(content: api.content)
  }
}

extension NotificationDetailsApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
