import Dependencies
import Foundation
import InvitationService
import Observation

@MainActor @Observable
final class NetworkQRCodeViewModel {
  private(set) var state: State = .loading
  private(set) var notice: Notice?
  var destination: Destination?

  let onDismiss: () -> Void

  var invitation: InvitationCode? {
    guard case let .ready(invitation) = state else { return nil }
    return invitation
  }

  var activeInvitation: InvitationCode? {
    guard let invitation, invitation.expiration > now else { return nil }
    return invitation
  }

  var refreshDeadline: Date? {
    switch state {
    case let .ready(invitation): invitation.expiration
    case let .refreshing(expiration): expiration
    case .loading, .failed: nil
    }
  }

  @ObservationIgnored @Dependency(\.continuousClock) private var clock
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(InvitationService.self) private var service
  private var didStart = false
  private var isSaving = false

  init(onDismiss: @escaping () -> Void) {
    self.onDismiss = onDismiss
  }

  func start() async {
    guard !didStart else { return }
    didStart = true
    await load(force: false)
  }

  func retry() async {
    guard case .failed = state else { return }
    await load(force: false)
  }

  func replaceCode() async {
    guard activeInvitation != nil else { return }
    if destination == .replace { destination = nil }
    await load(force: true)
  }

  func refreshAtExpiry(_ expiration: Date?) async {
    guard let expiration, invitation?.expiration == expiration else { return }
    do {
      while expiration > now {
        try await clock.sleep(for: .seconds(expiration.timeIntervalSince(now)))
      }
      try Task.checkCancellation()
    } catch {
      return
    }
    guard invitation?.expiration == expiration else { return }
    if destination == .replace { destination = nil }
    await load(force: false, loadingState: .refreshing(expiration: expiration))
  }

  func copyLink() async {
    guard let invitation = activeInvitation else { return }
    await service.copyLink(invitation.url)
    notice = .linkCopied
  }

  func saveImage() async {
    guard let invitation = activeInvitation, !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    let result: Notice
    do {
      try await service.saveImage(invitation.image)
      result = .imageSaved
    } catch {
      result = .saveFailed
    }
    guard activeInvitation?.url == invitation.url else { return }
    notice = result
  }

  enum State {
    case loading
    case refreshing(expiration: Date)
    case failed
    case ready(InvitationCode)
  }

  enum Notice {
    case linkCopied
    case imageSaved
    case saveFailed
  }
}

private extension NetworkQRCodeViewModel {
  private func load(force: Bool, loadingState: State = .loading) async {
    notice = nil
    state = loadingState
    do {
      let invitation = try await service.generateInvitation(force)
      guard !Task.isCancelled else { return }
      guard invitation.expiration > now else {
        state = .failed
        return
      }
      state = .ready(invitation)
    } catch {
      guard !Task.isCancelled else { return }
      state = .failed
    }
  }
}
