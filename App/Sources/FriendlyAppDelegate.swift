import Dependencies
import Foundation
import NotificationDetailsApi
import PushRegistrationService
import UIKit
import UserNotifications

final class FriendlyAppDelegate: NSObject, UIApplicationDelegate {
  nonisolated let notificationResponses = NotificationResponseStore()
  @Dependency(PushRegistrationService.self) private var pushRegistration

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    pushRegistration.receivedAPNsToken(token: deviceToken)
  }
}

extension FriendlyAppDelegate: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping @Sendable () -> Void
  ) {
    notificationResponses.receive(Self.selection(from: response), completion: completionHandler)
  }
}

private extension FriendlyAppDelegate {
  nonisolated private static func selection(
    from response: UNNotificationResponse
  ) -> NotificationSelection? {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
          let rawID = response.notification.request.content.userInfo["id"] as? String,
          let id = Int64(rawID), id > 0 else { return nil }
    let encoded = response.notification.request.content.userInfo["friendly.context"] as? String
    let context = encoded.flatMap {
      try? JSONDecoder().decode(NotificationContext.self, from: Data($0.utf8))
    }
    return NotificationSelection(id: id, context: context)
  }
}
