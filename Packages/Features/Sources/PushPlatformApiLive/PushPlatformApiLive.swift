import FirebaseCore
import FirebaseMessaging
import Foundation
import UIKit

@MainActor
final class PushPlatformApiLive: NSObject {
  private var onToken: (@Sendable (String) -> Void)?

  override nonisolated init() { super.init() }

  func configureFirebase(onToken: @escaping @Sendable (String) -> Void) -> Bool {
    guard configureAppIfNeeded() else { return false }
    self.onToken = onToken
    Messaging.messaging().delegate = self
    return true
  }

  func registerForRemoteNotifications() {
    UIApplication.shared.registerForRemoteNotifications()
  }

  func openNotificationSettings() async {
    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
    _ = await UIApplication.shared.open(url)
  }

  func token(apnsToken: Data) async throws -> String {
    let messaging = Messaging.messaging()
    if messaging.apnsToken != apnsToken { messaging.apnsToken = apnsToken }
    return try await messaging.token()
  }

  func deleteToken() async throws {
    try await Messaging.messaging().deleteToken()
  }
}

extension PushPlatformApiLive: MessagingDelegate {
  nonisolated func messaging(
    _ messaging: Messaging,
    didReceiveRegistrationToken fcmToken: String?
  ) {
    guard let fcmToken else { return }
    Task { @MainActor [weak self] in self?.onToken?(fcmToken) }
  }
}

private extension PushPlatformApiLive {
  private func configureAppIfNeeded() -> Bool {
    if FirebaseApp.app() != nil { return true }
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let options = FirebaseOptions(contentsOfFile: path),
          options.bundleID == Bundle.main.bundleIdentifier else { return false }
    FirebaseApp.configure(options: options)
    return true
  }
}
