import ActivityService
@testable import CommunityFeature
import CommunityService
import CustomDump
import Dependencies
import Synchronization
import Testing

@MainActor
struct CommunityActivityBadgeTests {
  @Test func refreshShowsAndClearsBadgeUsingBackendState() async {
    let unread = Mutex(true)
    var service = ActivityService()
    service.hasNewUnreads = { _ in unread.withLock { $0 } }
    let model = makeModel(service)
    await model.refreshActivity()
    expectNoDifference(model.hasNewActivity, true)
    unread.withLock { $0 = false }
    await model.refreshActivity()
    expectNoDifference(model.hasNewActivity, false)
  }

  @Test func failedRefreshPreservesKnownBadge() async {
    let fails = Mutex(false)
    var service = ActivityService()
    service.hasNewUnreads = { _ in
      if fails.withLock({ $0 }) { throw ActivityError.unavailable }
      return true
    }
    let model = makeModel(service)
    await model.refreshActivity()
    fails.withLock { $0 = true }
    await model.refreshActivity()
    expectNoDifference(model.hasNewActivity, true)
    #expect(model.error == nil)
  }

  @Test func staleResponseDoesNotShowBadgeForAnotherSession() async {
    let current = Mutex(true)
    var service = ActivityService()
    service.hasNewUnreads = { _ in
      current.withLock { $0 = false }
      return true
    }
    let model = makeModel(service, isCurrent: { current.withLock { $0 } })
    await model.refreshActivity()
    expectNoDifference(model.hasNewActivity, false)
  }

  @Test func cancelledResponseDoesNotShowBadge() async {
    var service = ActivityService()
    service.hasNewUnreads = { _ in
      withUnsafeCurrentTask { $0?.cancel() }
      return true
    }
    let model = makeModel(service)
    await Task { await model.refreshActivity() }.value
    expectNoDifference(model.hasNewActivity, false)
  }

  @Test func unauthorizedRefreshUsesExistingSignOutFlow() async {
    var unauthorized = false
    var service = ActivityService()
    service.hasNewUnreads = { _ in throw CommunityError.unauthorized }
    let model = makeModel(service, onUnauthorized: { unauthorized = true })
    await model.refreshActivity()
    #expect(unauthorized)
    expectNoDifference(model.hasNewActivity, false)
  }
}

private extension CommunityActivityBadgeTests {
  private func makeModel(
    _ activity: ActivityService, isCurrent: @escaping () -> Bool = { true },
    onUnauthorized: @escaping () -> Void = {}
  ) -> CommunityViewModel {
    withDependencies {
      $0[ActivityService.self] = activity
    } operation: {
      makeFeedModel(service: .init(), drafts: .init(load: { nil }, save: { _ in }, remove: {}),
                    isCurrentSession: isCurrent, onUnauthorized: onUnauthorized)
    }
  }
}
