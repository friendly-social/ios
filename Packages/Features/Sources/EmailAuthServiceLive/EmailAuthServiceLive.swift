import AccountSessionService
import AccountStorageService
import AuthApi
import Dependencies
import EmailAuthService
import Models
import ProfileApi

struct EmailAuthServiceLive: Sendable {
  @Dependency(AuthApi.self) private var authApi
  @Dependency(ProfileApi.self) private var profileApi
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(AccountSessionService.self) private var accountSession

  func requestBindingCode(email: String) async throws {
    let authorization = try storage.loadAuthorization()
    do {
      try await authApi.emailLink(authorization, email)
    } catch {
      try checkCurrentSession(authorization)
      switch error {
      case AuthApi.EmailLinkError.alreadyUsed: throw EmailAuthError.alreadyUsed
      case AuthApi.EmailLinkError.unauthorized: throw EmailAuthError.unauthorized
      default: throw EmailAuthError.networkError
      }
    }
    try checkCurrentSession(authorization)
  }

  func confirmBinding(email: String, code: Int) async throws {
    let authorization = try storage.loadAuthorization()
    do {
      try await authApi.emailConfirm(authorization, code)
    } catch AuthApi.EmailConfirmError.unauthorized {
      try checkCurrentSession(authorization)
      throw EmailAuthError.unauthorized
    } catch {
      try await recoverConfirmation(email: email, authorization: authorization, error: error)
      return
    }
    try checkCurrentSession(authorization)
  }

  func requestLoginCode(email: String) async throws {
    do {
      try await authApi.authEmail(email)
      try Task.checkCancellation()
    } catch AuthApi.AuthEmailError.unknownEmail {
      throw EmailAuthError.unknownEmail
    } catch {
      try Task.checkCancellation()
      throw EmailAuthError.networkError
    }
  }

  func login(email: String, code: Int) async throws {
    do {
      let authorization = try await authApi.authLogin(email, code)
      try Task.checkCancellation()
      accountSession.clearAuthorization()
      try storage.saveAuthorization(authorization)
    } catch AuthApi.AuthLoginError.invalidOrExpiredCode {
      throw EmailAuthError.invalidCode
    } catch {
      try Task.checkCancellation()
      throw EmailAuthError.networkError
    }
  }
}

private extension EmailAuthServiceLive {
  private func recoverConfirmation(
    email: String,
    authorization: Authorization,
    error: Error
  ) async throws {
    try checkCurrentSession(authorization)
    let user = try? await profileApi.usersDetails(
      authorization,
      authorization.id,
      authorization.accessHash
    )
    try checkCurrentSession(authorization)
    // Confirmation can commit even if its response is lost.
    if user?.email == email { return }
    if case AuthApi.EmailConfirmError.invalidOrExpiredCode = error {
      throw EmailAuthError.invalidCode
    }
    throw EmailAuthError.networkError
  }

  private func checkCurrentSession(_ authorization: Authorization) throws {
    try Task.checkCancellation()
    let current = try storage.loadAuthorization()
    guard current.id == authorization.id, current.token == authorization.token else {
      throw CancellationError()
    }
  }
}
