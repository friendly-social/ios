import AccountStorageService
import AuthApi
import Dependencies
import Models
import OSLog

actor PushTokenRegistrationServiceLive {
  @Dependency(AccountStorageService.self) private var accounts
  @Dependency(AuthApi.self) private var api
  private var uploadedRegistration: Registration?

  func upload(firebaseToken: String, authorization: Authorization) async throws {
    try validate(authorization)
    try shareSession(authorization)
    try validate(authorization)
    let registration = Registration(sessionToken: authorization.token, firebaseToken: firebaseToken)
    guard registration != uploadedRegistration else { return }
    try await api.registerFirebaseToken(authorization: authorization, firebaseToken: firebaseToken)
    try validate(authorization)
    uploadedRegistration = registration
  }

  func reset() {
    uploadedRegistration = nil
  }
}

private extension PushTokenRegistrationServiceLive {
  private struct Registration: Equatable {
    let sessionToken: Token
    let firebaseToken: String
  }

  private func validate(_ authorization: Authorization) throws {
    try Task.checkCancellation()
    guard let current = try? accounts.loadAuthorization(),
          current.id == authorization.id,
          current.token == authorization.token else { throw CancellationError() }
  }

  private func shareSession(_ authorization: Authorization) throws {
    do {
      try accounts.shareNotificationSession(authorization: authorization)
    } catch let error as CancellationError {
      throw error
    } catch {
      Constants.logger.error("Could not share the notification session: \(error)")
    }
  }
}

private enum Constants {
  static let logger = Logger(subsystem: "me.y9san9.Friendly", category: "PushRegistration")
}
