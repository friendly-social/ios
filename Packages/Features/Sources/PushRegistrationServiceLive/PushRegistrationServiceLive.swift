import AccountStorageService
import CryptoKit
import Dependencies
import Foundation
import Models
import OSLog
import PushPlatformApi
import PushRegistrationService
import PushTokenRegistrationService
import StorageService
import UserNotifications

actor PushRegistrationServiceLive {
  @Dependency(AccountStorageService.self) private var accounts
  @Dependency(PushPlatformApi.self) private var platform
  @Dependency(PushTokenRegistrationService.self) private var tokenRegistrationService
  @Dependency(SecureStorageService.self) private var secureStorage
  private var deviceToken: Data?
  private var observedToken: String?
  private var worker: Task<Void, Never>?
  private var refreshRequested = false
  private var isRequestingAuthorization = false

  func authorizationStatus() async -> PushAuthorizationStatus {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined: return .notDetermined
    case .authorized, .provisional, .ephemeral: return .authorized
    default: return .denied
    }
  }

  func requestAuthorizationIfNeeded() async {
    guard !isRequestingAuthorization,
          let authorization = try? accounts.loadAuthorization() else { return }
    isRequestingAuthorization = true
    defer { isRequestingAuthorization = false }
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .notDetermined,
          !Task.isCancelled,
          (try? accounts.loadAuthorization().token) == authorization.token else { return }
    do {
      if try await center.requestAuthorization(options: [.alert]) { refresh() }
    } catch {
      Constants.logger.error("Could not request notification authorization: \(error)")
    }
  }

  func openNotificationSettings() async {
    await platform.openNotificationSettings()
  }

  func refresh() {
    refreshRequested = true
    guard worker == nil else { return }
    worker = Task { [weak self] in await self?.processRefreshes() }
  }

  func receiveAPNsToken(_ token: Data) {
    deviceToken = token
    refresh()
  }
}

private extension PushRegistrationServiceLive {
  private func processRefreshes() async {
    while refreshRequested {
      refreshRequested = false
      await reconcileRegistration()
    }
    worker = nil
  }

  private func reconcileRegistration() async {
    guard await configureFirebase() else { return }
    do {
      guard try accounts.hasAuthorization() else {
        try await invalidateTokenIfNeeded()
        return
      }
      guard let deviceToken else {
        await platform.registerForRemoteNotifications()
        return
      }
      let authorization = try accounts.loadAuthorization()
      try await registerToken(for: authorization, apnsToken: deviceToken)
    } catch is CancellationError {
      return
    } catch {
      Constants.logger.error("Could not synchronize push registration: \(error)")
    }
  }

  private func configureFirebase() async -> Bool {
    await platform.configureFirebase(
      onToken: { [weak self] token in
        Task { await self?.receiveFCMToken(token) }
      }
    )
  }

  private func receiveFCMToken(_ token: String) {
    guard observedToken != token else { return }
    observedToken = token
    refresh()
  }

  private func registerToken(for authorization: Authorization, apnsToken: Data) async throws {
    try await prepareToken(for: authorization)
    guard isCurrentSession(authorization) else { return }
    let firebaseToken = try await platform.token(apnsToken: apnsToken)
    observedToken = firebaseToken
    guard isCurrentSession(authorization), deviceToken == apnsToken else { return }
    try await tokenRegistrationService.upload(
      firebaseToken: firebaseToken,
      authorization: authorization
    )
  }

  private func prepareToken(for authorization: Authorization) async throws {
    let sessionKey = Data(SHA256.hash(data: Data(authorization.token.string.utf8)))
    let previousSessionKey = try secureStorage.load(Constants.sessionKey)
    guard previousSessionKey != sessionKey else { return }
    if previousSessionKey != nil { try await invalidateTokenIfNeeded() }
    guard isCurrentSession(authorization) else { return }
    try secureStorage.save(sessionKey, Constants.sessionKey)
  }

  private func isCurrentSession(_ authorization: Authorization) -> Bool {
    (try? accounts.loadAuthorization().token) == authorization.token
  }

  private func invalidateTokenIfNeeded() async throws {
    guard try secureStorage.contains(Constants.sessionKey) else { return }
    try await platform.deleteToken()
    try secureStorage.remove(Constants.sessionKey)
    observedToken = nil
    await tokenRegistrationService.reset()
  }
}

private enum Constants {
  static let logger = Logger(subsystem: "me.y9san9.Friendly", category: "PushRegistration")
  static let sessionKey = "push.firebase.tokenSession"
}
