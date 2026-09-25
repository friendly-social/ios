import AccountStorageService
import AccountSessionService
import AuthApi
import Dependencies
import EmailAuthService
import Foundation

struct EmailAuthServiceLive: Sendable {
  @Dependency(AuthApi.self) private var authApi
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(AccountSessionService.self) private var accountSession

  func requestBindingCode(email: String) async throws {
    let authorization = try storage.loadAuthorization()
    do {
      try await authApi.emailLink(authorization, email)
      try Task.checkCancellation()
    } catch AuthApi.EmailLinkError.alreadyUsed {
      throw EmailAuthError.alreadyUsed
    } catch AuthApi.EmailLinkError.unauthorized {
      throw EmailAuthError.unauthorized
    } catch {
      try Task.checkCancellation()
      throw EmailAuthError.networkError
    }
  }

  func confirmBinding(code: Int) async throws {
    let authorization = try storage.loadAuthorization()
    do {
      try await authApi.emailConfirm(authorization, code)
      try Task.checkCancellation()
    } catch AuthApi.EmailConfirmError.invalidOrExpiredCode {
      throw EmailAuthError.invalidCode
    } catch AuthApi.EmailConfirmError.unauthorized {
      throw EmailAuthError.unauthorized
    } catch {
      try Task.checkCancellation()
      throw EmailAuthError.networkError
    }
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
