import CommunityFeature
import Observation

@MainActor @Observable
public final class CommunityRootViewModel {
  private(set) var feed: CommunityViewModel?
  let onSessionExpired: () -> Void

  public init(onSessionExpired: @escaping () -> Void) {
    self.onSessionExpired = onSessionExpired
  }

  func start() {
    guard feed == nil else { return }
    let model = CommunityViewModel(onUnauthorized: onSessionExpired)
    guard model.start() else { return }
    feed = model
  }
}
