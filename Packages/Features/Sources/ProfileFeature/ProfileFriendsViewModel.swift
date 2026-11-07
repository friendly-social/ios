import Dependencies
import Models
import Observation
import ProfileService

@MainActor @Observable
final class ProfileFriendsViewModel {
  enum Destination: Hashable, Identifiable {
    case profile(id: UserId, accessHash: UserAccessHash)

    var id: Self { self }
  }

  @ObservationIgnored @Dependency(ProfileService.self) private var service
  private(set) var friends: [FriendSummary]
  private(set) var refreshFailed = false
  private let selection: ProfileSelection
  private var reloadTask: Task<Void, Never>?
  var destination: Destination?

  init(friends: [FriendSummary], selection: ProfileSelection) {
    self.friends = friends
    self.selection = selection
  }

  var isOwn: Bool {
    if case .current = selection { return true }
    return false
  }

  func reload() async {
    reloadTask?.cancel()
    let task = Task<Void, Never> { [weak self] in await self?.performReload() }
    reloadTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

  func showProfile(_ friend: FriendSummary) {
    destination = .profile(id: friend.id, accessHash: friend.accessHash)
  }
}

private extension ProfileFriendsViewModel {
  private func performReload() async {
    guard !Task.isCancelled else { return }
    refreshFailed = false
    do {
      let updated: [FriendSummary]?
      switch selection {
      case .current: updated = try await service.loadFriends()
      case .other:
        updated = try await service.loadProfile(selection)?.commonFriends
      }
      try Task.checkCancellation()
      guard let updated else { return }
      friends = updated
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      refreshFailed = true
    }
  }
}
