import Dependencies
import NotificationEnrichmentService
import Synchronization
import UserNotifications

final class NotificationServiceExtension: UNNotificationServiceExtension {
  @Dependency(NotificationEnrichmentService.self) private var enrichment
  private let activeDelivery = Mutex<NotificationDeliveryContext?>(nil)

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    let delivery = NotificationDeliveryContext(
      original: request.content,
      contentHandler: contentHandler
    )
    replaceActiveDelivery(with: delivery)?.finish()
    delivery.start { [enrichment] in await enrichment.content(request: request) }
  }

  override func serviceExtensionTimeWillExpire() {
    replaceActiveDelivery(with: nil)?.finish()
  }
}

private extension NotificationServiceExtension {
  private func replaceActiveDelivery(
    with delivery: NotificationDeliveryContext?
  ) -> NotificationDeliveryContext? {
    activeDelivery.withLock { current in
      defer { current = delivery }
      return current
    }
  }
}
