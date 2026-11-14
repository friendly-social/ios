import CommunityProfileService
import Dependencies
import Foundation
import FriendAccessService
import Models
import NotificationDetailsApi
import NotificationOpeningService
import ProfileFormService
import SwiftUI

@MainActor
@Observable
final class AppViewModel {
  @ObservationIgnored @Dependency(NotificationOpeningService.self) private var notifications
  var destination: Destination?

  @ObservationIgnored @Dependency(ProfileFormService.self) var profileFormService
  @ObservationIgnored @Dependency(FriendAccessService.self) private var friendAccessService
  private(set) var screen: Screen = .empty
  private var activeInvite: ActiveInvite?

  private(set) var isProcessingFriendAccess: Bool = false
  var friendLinkAlert: FriendLinkAlert?
  var mainRoute: MainRoute?

  func appear() {
    guard !isProcessingFriendAccess else { return }
    do {
      switch try friendAccessService.initialAccess() {
      case .signedOut:
        screen = .signUp
      case .reconcile:
        reconcileFriendAccess()
      case .main:
        screen = .main
      case .addFriend:
        screen = .qrAddFriend
      }
    } catch {
      friendAccessService.invalidateAuthorization()
      screen = .signUp
    }
  }

  func onSignUp() {
    screen = .qrAddFriend
  }

  func onAddFriendWithQr() {
    mainRoute = .feed
    screen = .main
  }

  func open(_ url: URL) {
    guard let deeplink = Deeplink.parseOf(url: url) else {
      onInvalidFriendLink()
      return
    }
    switch deeplink {
    case let .addFriend(token):
      onAddFriend(token: token)
    }
  }

  func onEmailLogin() {
    friendAccessService.completeEmailLogin()
    mainRoute = .community
    screen = .main
  }

  func signOut() {
    destination = nil
    friendAccessService.invalidateAuthorization()
    friendAccessService.clearPendingReconciliation()
    activeInvite = nil
    mainRoute = nil
    screen = .signUp
  }

  func routeToSignUp() {
    destination = nil
    activeInvite = nil
    mainRoute = nil
    friendAccessService.clearPendingReconciliation()
    appear()
  }

  func onAddFriend(token: FriendToken) {
    guard !isProcessingFriendAccess else {
      friendLinkAlert = .alreadyProcessing
      return
    }
    guard activeInvite == nil else {
      friendLinkAlert = .retryInvite
      return
    }
    do {
      guard try prepareInvite(AddFriendCommand(token: token)) else { return }
      addActiveInvite()
    } catch {
      friendAccessService.invalidateAuthorization()
      screen = .signUp
      friendLinkAlert = .authenticationRequired
    }
  }

  func onInvalidFriendLink() {
    guard !isProcessingFriendAccess else {
      friendLinkAlert = .alreadyProcessing
      return
    }
    guard activeInvite == nil else {
      friendLinkAlert = .retryInvite
      return
    }
    friendLinkAlert = .invalidInvite
  }

  func retryFriendLink() {
    guard activeInvite != nil else { return }
    addActiveInvite()
  }

  func cancelFriendLink() {
    activeInvite = nil
  }

  func retryFriendAccessReconciliation() {
    reconcileFriendAccess()
  }

  private struct ActiveInvite {
    let command: AddFriendCommand
  }

  enum FriendLinkAlert: Int, Identifiable {
    case authenticationRequired
    case alreadyProcessing
    case invalidInvite
    case retryInvite
    case retryReconciliation

    var id: Int { rawValue }

    var title: LocalizedStringResource {
      switch self {
      case .authenticationRequired:
        .friendLinkAuthRequiredTitle
      case .alreadyProcessing:
        .friendLinkProcessingTitle
      case .invalidInvite:
        .friendLinkInvalidTitle
      case .retryInvite:
        .friendLinkRetryTitle
      case .retryReconciliation:
        .friendGateRetryTitle
      }
    }

    var message: LocalizedStringResource {
      switch self {
      case .authenticationRequired:
        .friendLinkAuthRequiredMessage
      case .alreadyProcessing:
        .friendLinkProcessingMessage
      case .invalidInvite:
        .friendLinkInvalidMessage
      case .retryInvite:
        .friendLinkRetryMessage
      case .retryReconciliation:
        .friendGateRetryMessage
      }
    }
  }
}

extension AppViewModel {
  func loadNotification(id: UUID) async {
    guard case var .notification(notification) = destination,
      notification.id == id, notification.content == nil, !notification.isLoading
    else { return }
    guard let session = notification.session ?? notifications.currentSession() else {
      routeToSignUp()
      return
    }
    notification.session = session
    notification.isLoading = true
    notification.failed = false
    destination = .notification(notification)
    defer { finishNotificationLoading(id: id) }
    await resolveNotification(notification, session: session)
  }
}

private extension AppViewModel {
  private func addActiveInvite() {
    guard let activeInvite else { return }
    isProcessingFriendAccess = true
    friendLinkAlert = nil
    Task { [weak self] in
      await self?.submitInvite(activeInvite.command)
    }
  }

  private func prepareInvite(_ command: AddFriendCommand) throws -> Bool {
    guard try friendAccessService.hasAuthorization() else {
      screen = .signUp
      friendLinkAlert = .authenticationRequired
      return false
    }
    let hasFriend = try friendAccessService.hasFriendAccess()
    screen = hasFriend || screen == .main ? .main : .qrAddFriend
    activeInvite = ActiveInvite(command: command)
    return true
  }

  private func submitInvite(_ command: AddFriendCommand) async {
    do {
      try await friendAccessService.addFriend(command)
      activeInvite = nil
      isProcessingFriendAccess = false
      friendLinkAlert = nil
      mainRoute = .feed
      screen = .main
    } catch let error as FriendAccessError {
      isProcessingFriendAccess = false
      handleInviteFailure(error)
    } catch {
      isProcessingFriendAccess = false
      friendLinkAlert = .retryInvite
    }
  }

  private func handleInviteFailure(_ error: FriendAccessError) {
    switch error {
    case .alreadyProcessing:
      activeInvite = nil
      friendLinkAlert = .alreadyProcessing
    case .invalidInvite:
      activeInvite = nil
      friendLinkAlert = .invalidInvite
    case .retryable:
      friendLinkAlert = .retryInvite
    }
  }

  private func reconcileFriendAccess() {
    guard !isProcessingFriendAccess else { return }
    isProcessingFriendAccess = true
    friendLinkAlert = nil
    Task { [weak self] in
      await self?.reconcileAccess()
    }
  }

  private func reconcileAccess() async {
    do {
      let hasFriend = try await friendAccessService.reconcileFriendAccess()
      isProcessingFriendAccess = false
      friendLinkAlert = nil
      if hasFriend {
        mainRoute = .feed
        screen = .main
      } else {
        screen = .qrAddFriend
      }
    } catch {
      isProcessingFriendAccess = false
      routeUsingStoredFriendState()
      friendLinkAlert = .retryReconciliation
    }
  }

  private func routeUsingStoredFriendState() {
    do {
      screen = try friendAccessService.hasFriendAccess()
        ? .main
        : .qrAddFriend
    } catch {
      friendAccessService.invalidateAuthorization()
      screen = .signUp
    }
  }

  private func resolveNotification(_ pending: Notification, session: CommunitySession) async {
    var notification = pending
    let id = notification.id
    do {
      let content = try await notifications.open(
        selection: notification.selection,
        session: session
      )
      guard !Task.isCancelled, notifications.isCurrentSession(session), destination?.id == id
      else { return }
      notification.content = content
      destination = .notification(notification)
    } catch is CancellationError {
      return
    } catch NotificationOpeningError.unauthorized {
      if !Task.isCancelled, destination?.id == id, notifications.currentSession() == nil {
        routeToSignUp()
      }
    } catch {
      guard !Task.isCancelled, notifications.isCurrentSession(session), destination?.id == id
      else { return }
      notification.failed = true
      destination = .notification(notification)
    }
  }

  private func finishNotificationLoading(id: UUID) {
    guard case var .notification(notification) = destination, notification.id == id else { return }
    notification.isLoading = false
    destination = .notification(notification)
  }
}
