import CommunityFeature
import CommunityService
import Models
import Observation
import ProfileFeature

@MainActor @Observable
public final class CommunityRootViewModel {
  private(set) var feed: CommunityViewModel?
  var author: AuthorDestination?
  private let onSessionExpired: () -> Void

  public init(onSessionExpired: @escaping () -> Void) {
    self.onSessionExpired = onSessionExpired
  }

  func start() {
    guard feed == nil else { return }
    let model = CommunityViewModel(onUnauthorized: onSessionExpired)
    guard model.start() else { return }
    feed = model
  }

  func openAuthor(_ owner: CommunityPost.Owner) {
    guard let accessHash = try? UserAccessHash(owner.accessHash) else { return }
    author = AuthorDestination(id: owner.id, accessHash: accessHash)
  }

  func closeAuthor() {
    author = nil
  }

  struct AuthorDestination: Identifiable {
    let id: Int64
    let accessHash: UserAccessHash

    var profile: ProfileView.OtherProfile {
      .init(id: UserId(id), accessHash: accessHash)
    }
  }
}
