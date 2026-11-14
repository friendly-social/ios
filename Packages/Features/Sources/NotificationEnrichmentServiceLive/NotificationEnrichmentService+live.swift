import Dependencies
import NotificationEnrichmentService

private extension NotificationEnrichmentService {
  static func live() -> Self {
    let service = NotificationEnrichmentServiceLive()
    return Self(content: service.content)
  }
}

extension NotificationEnrichmentService: DependencyKey {
  public static var liveValue: Self { .live() }
}
