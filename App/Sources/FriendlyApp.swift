import Dependencies
import ImageService
import PushRegistrationService
import SwiftUI

@main
struct FriendlyApp: App {
  @UIApplicationDelegateAdaptor(FriendlyAppDelegate.self) private var appDelegate
  @Dependency(ImageService.self) private var images
  @Dependency(PushRegistrationService.self) private var pushRegistration
  @Environment(\.scenePhase) private var scenePhase

  init() { images.prepare() }

  var body: some Scene {
    WindowGroup { AppView(notificationResponses: appDelegate.notificationResponses) }
      .onChange(of: scenePhase, initial: true) {
        if scenePhase == .active { pushRegistration.refresh() }
      }
  }
}
