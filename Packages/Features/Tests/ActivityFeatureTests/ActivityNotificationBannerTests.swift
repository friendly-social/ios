@testable import ActivityFeature
import ActivityService
import CommunityProfileService
import Dependencies
import PushRegistrationService
import Synchronization
import Testing

@MainActor
struct ActivityNotificationBannerTests {
  @Test func openingActivityNeverRequestsPermissionAutomatically() async {
    var push = PushRegistrationService()
    push.authorizationStatus = { .notDetermined }
    push.requestAuthorizationIfNeeded = {
      Issue.record("Opening Activity must not show the system prompt")
    }
    let model = withDependencies {
      $0[PushRegistrationService.self] = push
    } operation: { makeModel() }
    await model.refreshNotificationAuthorization()
    #expect(model.showsNotificationBanner)
    #expect(model.notificationAuthorization == .notDetermined)
  }

  @Test func allowingNotificationsHidesTheBannerBeforeBackendRegistrationCompletes() async {
    let status = Mutex(PushAuthorizationStatus.notDetermined)
    let prompts = Mutex(0)
    let registrations = Mutex(0)
    var push = PushRegistrationService()
    push.authorizationStatus = { status.withLock { $0 } }
    push.requestAuthorizationIfNeeded = {
      prompts.withLock { $0 += 1 }
      status.withLock { $0 = .authorized }
    }
    push.refresh = { registrations.withLock { $0 += 1 } }
    let model = withDependencies {
      $0[PushRegistrationService.self] = push
    } operation: { makeModel() }
    await model.refreshNotificationAuthorization()
    await model.notificationBannerTapped()
    #expect(!model.showsNotificationBanner)
    #expect(prompts.withLock { $0 } == 1)
    #expect(registrations.withLock { $0 } == 1)
  }

  @Test func deniedBannerOpensSettingsAndDisappearsAfterPermissionChanges() async {
    let status = Mutex(PushAuthorizationStatus.denied)
    let settings = Mutex(0)
    var push = PushRegistrationService()
    push.authorizationStatus = { status.withLock { $0 } }
    push.requestAuthorizationIfNeeded = { Issue.record("Denied permission must open Settings") }
    push.openNotificationSettings = { settings.withLock { $0 += 1 } }
    push.refresh = {}
    let model = withDependencies {
      $0[PushRegistrationService.self] = push
    } operation: { makeModel() }
    await model.refreshNotificationAuthorization()
    await model.notificationBannerTapped()
    #expect(model.showsNotificationBanner)
    #expect(settings.withLock { $0 } == 1)
    status.withLock { $0 = .authorized }
    await model.refreshNotificationAuthorization()
    #expect(!model.showsNotificationBanner)
    status.withLock { $0 = .denied }
    await model.refreshNotificationAuthorization()
    #expect(model.showsNotificationBanner)
  }

  @Test func activityNetworkFailureDoesNotHideThePermissionBanner() async {
    var push = PushRegistrationService()
    push.authorizationStatus = { .notDetermined }
    let model = withDependencies {
      $0[PushRegistrationService.self] = push
    } operation: { makeModel() }
    await model.refreshNotificationAuthorization()
    await model.start()
    #expect(model.error != nil)
    #expect(model.events.isEmpty)
    #expect(model.showsNotificationBanner)
  }
}

private extension ActivityNotificationBannerTests {
  private func makeModel() -> ActivityViewModel {
    withDependencies {
      $0[CommunityProfileService.self].currentSession = {
        .init(accountID: 7, token: "test-token", sessionID: "test-session")
      }
      $0[CommunityProfileService.self].isCurrentSession = { _ in true }
      $0[ActivityService.self].list = { _, _ in throw ActivityError.unavailable }
    } operation: { ActivityViewModel(onUnauthorized: {}) }
  }
}
