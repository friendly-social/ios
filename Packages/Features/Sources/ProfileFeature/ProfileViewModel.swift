import CommunityMarkdownService
import Dependencies
import Foundation
import FriendlyUIKit
import Models
import Observation
import ProfileFormService
import ProfileService

@MainActor @Observable
final class ProfileViewModel {
  @ObservationIgnored @Dependency(ProfileFormService.self) var profileFormService
  @ObservationIgnored @Dependency(ProfileService.self) private var service
  private let mode: ProfileView.Mode
  private var reloadTask: Task<Void, Never>?
  private var friendsTask: Task<Void, Never>?
  private(set) var state: State = .loading
  private(set) var descriptionDocument: MarkdownDocument?
  private(set) var friendsState: FriendsState = .loading
  private(set) var friendsRefreshFailed = false
  private(set) var alertError: AlertError?
  private(set) var isUpdatingFriendship = false
  private(set) var shouldDismiss = false
  var destination: Destination?

  init(mode: ProfileView.Mode) {
    self.mode = mode
  }

  var enableSignOut: Bool {
    if case .selfProfile = mode { return true }
    return false
  }

  var profileSelection: ProfileSelection {
    switch mode {
    case .selfProfile: .current
    case let .otherProfile(profile): .other(id: profile.id, accessHash: profile.accessHash)
    }
  }

  var enableEdit: Bool {
    guard enableSignOut, case .success = state else { return false }
    return true
  }

  var enableRemoveFromFriends: Bool {
    guard case let .success(profile) = state,
      case .other(friendship: .friends, commonFriends: _) = profile.relationship else { return false }
    return true
  }

  var displayedFriends: [FriendSummary]? {
    if case let .success(profile) = state, let friends = profile.commonFriends { return friends }
    if case let .loaded(friends) = friendsState, enableSignOut { return friends }
    return nil
  }

  var commonFriendsPreview: FriendsPreview? {
    guard let friends = displayedFriends, !friends.isEmpty else { return nil }
    return FriendsPreview(friends: friends)
  }

  var socialLinkDestination: URL? {
    guard case let .success(profile) = state, let url = profile.info.socialUrl else { return nil }
    guard url.scheme == nil else { return url }
    return URL(string: "https://\(url.absoluteString)")
  }

  func showEditProfile() { destination = .edit }
  func editProfileDismissed() { startReload() }
  func appear() { startReload() }
  func clearAlertError() { alertError = nil }
  func showInvitation() { destination = .invitation }

  func reload() async {
    let task = makeReloadTask()
    await task.value
  }

  func signOut() {
    guard case let .selfProfile(profile) = mode else { return }
    reloadTask?.cancel()
    friendsTask?.cancel()
    service.signOut()
    profile.routeToSignUp()
  }

  func requestFriend() async {
    guard case let .otherProfile(profile) = mode, !isUpdatingFriendship else { return }
    isUpdatingFriendship = true
    defer { isUpdatingFriendship = false }
    do {
      try await service.requestFriend(profile.id, profile.accessHash)
      await reload()
    } catch is CancellationError {
      return
    } catch {
      alertError = .request
    }
  }

  func friendsDecline() async {
    guard case let .otherProfile(profile) = mode, !isUpdatingFriendship else { return }
    isUpdatingFriendship = true
    defer { isUpdatingFriendship = false }
    do {
      try await service.declineFriend(profile.id, profile.accessHash)
      shouldDismiss = true
    } catch is CancellationError {
      return
    } catch {
      alertError = .decline
    }
  }

  enum State {
    case loading, success(LoadedProfile), ioError
  }

  enum AlertError { case decline, request }
  enum FriendsState { case loading, loaded([FriendSummary]), failed }

  func loadFriends() async {
    guard enableSignOut else { return }
    friendsTask?.cancel()
    let task = Task<Void, Never> { [weak self] in await self?.performFriendsReload() }
    friendsTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

}

private extension ProfileViewModel {
  private func performFriendsReload() async {
    guard !Task.isCancelled else { return }
    let hasLoadedFriends: Bool
    if case .loaded = friendsState { hasLoadedFriends = true } else { hasLoadedFriends = false }
    if !hasLoadedFriends { friendsState = .loading }
    friendsRefreshFailed = false
    do {
      guard let friends = try await service.loadFriends() else { return }
      try Task.checkCancellation()
      friendsState = .loaded(friends)
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      if hasLoadedFriends { friendsRefreshFailed = true }
      else { friendsState = .failed }
    }
  }

  private func startReload() { makeReloadTask() }

  @discardableResult
  private func makeReloadTask() -> Task<Void, Never> {
    reloadTask?.cancel()
    let task = Task<Void, Never> { [weak self] in
      await self?.performReload()
    }
    reloadTask = task
    return task
  }

  private func performReload() async {
    do {
      guard let profile = try await service.loadProfile(profileSelection) else { return }
      let document = await service.prepareDescription(profile.info.description.string)
      try Task.checkCancellation()
      descriptionDocument = document
      state = .success(profile)
      if case .own = profile.relationship { await loadFriends() }
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      state = .ioError
    }
  }
}
