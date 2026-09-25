import AuthApi
import Dependencies
import Foundation
import Models
import Networking

struct AuthApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func generate(
    _ nickname: Nickname,
    _ description: UserDescription,
    _ interests: [Interest],
    _ avatar: FileDescriptor?,
    _ socialLink: SocialLink?
  ) async throws -> Authorization {
    let body = GenerateBody(
      nickname: nickname.string, description: description.string,
      interests: interests.map(\.string), avatar: avatar.map(FileDTO.init),
      socialLink: socialLink?.string)
    do {
      let request = try HTTPClient.Request.post(options: .init(urlPath: "auth/generate"), body: body)
      let response: AuthResponse = try await client.push(request: request)
      do { return try response.authorization() }
      catch { throw AuthApi.AuthGenerateError.serverError }
    } catch is HTTPStatusError { throw AuthApi.AuthGenerateError.serverError }
      catch let error as AuthApi.AuthGenerateError { throw error }
      catch { throw AuthApi.AuthGenerateError.ioError(error) }
  }

  func requestEmailCode(_ email: String) async throws {
    let options = HTTPClient.Request.Options(urlPath: "auth/email", headers: localeHeaders)
    do {
      let request = try HTTPClient.Request.post(options: options, body: EmailBody(email: email))
      try await sendVoid(request)
    } catch let error as HTTPStatusError {
      throw error.response.statusCode == 401
        ? AuthApi.AuthEmailError.unknownEmail : .serverError
    } catch { throw AuthApi.AuthEmailError.ioError(error) }
  }

  func login(_ email: String, _ code: Int) async throws -> Authorization {
    do {
      let body = LoginBody(email: email, code: code)
      let request = try HTTPClient.Request.post(options: .init(urlPath: "auth/login"), body: body)
      let response: AuthResponse = try await client.push(request: request)
      do { return try response.authorization() }
      catch { throw AuthApi.AuthLoginError.serverError }
    } catch let error as HTTPStatusError {
      throw error.response.statusCode == 403
        ? AuthApi.AuthLoginError.invalidOrExpiredCode : .serverError
    } catch let error as AuthApi.AuthLoginError { throw error }
      catch { throw AuthApi.AuthLoginError.ioError(error) }
  }

  func linkEmail(_ authorization: Authorization, _ email: String) async throws {
    let options = HTTPClient.Request.Options(
      urlPath: "email/link", headers: authorizationHeaders(authorization, locale: true))
    do {
      let request = try HTTPClient.Request.post(options: options, body: EmailBody(email: email))
      try await sendVoid(request)
    } catch let error as HTTPStatusError {
      switch error.response.statusCode {
      case 401: throw AuthApi.EmailLinkError.unauthorized
      case 409: throw AuthApi.EmailLinkError.alreadyUsed
      default: throw AuthApi.EmailLinkError.serverError
      }
    } catch { throw AuthApi.EmailLinkError.ioError(error) }
  }

  func confirmEmail(_ authorization: Authorization, _ code: Int) async throws {
    let options = HTTPClient.Request.Options(
      urlPath: "email/confirm", headers: authorizationHeaders(authorization))
    do {
      let request = try HTTPClient.Request.post(options: options, body: ConfirmBody(code: code))
      try await sendVoid(request)
    } catch let error as HTTPStatusError {
      switch error.response.statusCode {
      case 401: throw AuthApi.EmailConfirmError.unauthorized
      case 403: throw AuthApi.EmailConfirmError.invalidOrExpiredCode
      default: throw AuthApi.EmailConfirmError.serverError
      }
    } catch { throw AuthApi.EmailConfirmError.ioError(error) }
  }

  func unlinkEmail(_ authorization: Authorization) async throws {
    let options = HTTPClient.Request.Options(
      urlPath: "email/unlink", headers: authorizationHeaders(authorization))
    do {
      try await sendVoid(.post(options: options))
    } catch let error as HTTPStatusError {
      throw error.response.statusCode == 401
        ? AuthApi.EmailUnlinkError.unauthorized : .serverError
    } catch { throw AuthApi.EmailUnlinkError.ioError(error) }
  }
}

private extension AuthApiLive {
  private func sendVoid(_ request: HTTPClient.Request) async throws {
    let response = try await client.send(request)
    guard response.statusCode == 200 else { throw HTTPStatusError(response: response) }
  }

  private func authorizationHeaders(_ authorization: Authorization, locale: Bool = false) -> [String: String] {
    var headers = [
      "Cache-Control": "no-cache",
      "X-Token": authorization.token.string,
      "X-User-Id": String(authorization.id.int64)
    ]
    if locale { headers.merge(localeHeaders) { _, new in new } }
    return headers
  }

  private var localeHeaders: [String: String] {
    let identifier = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
    let code = Locale(identifier: identifier).language.languageCode?.identifier ?? "en"
    return ["X-Locale": code == "ru" ? "ru" : "en"]
  }
}
