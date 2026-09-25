import DependenciesMacros
import Models

@DependencyClient
public struct AuthApi: Sendable {
  public var authGenerate: @Sendable (Nickname, UserDescription, [Interest], FileDescriptor?, SocialLink?) async throws -> Authorization
  public var authEmail: @Sendable (String) async throws -> Void
  public var authLogin: @Sendable (String, Int) async throws -> Authorization
  public var emailLink: @Sendable (Authorization, String) async throws -> Void
  public var emailConfirm: @Sendable (Authorization, Int) async throws -> Void
  public var emailUnlink: @Sendable (Authorization) async throws -> Void

  public enum AuthGenerateError: Error {
    case ioError(Error)
    case serverError
  }

  public enum AuthEmailError: Error {
    case ioError(Error)
    case serverError
    case unknownEmail
  }

  public enum AuthLoginError: Error {
    case ioError(Error)
    case serverError
    case invalidOrExpiredCode
  }

  public enum EmailLinkError: Error {
    case ioError(Error)
    case serverError
    case unauthorized
    case alreadyUsed
  }

  public enum EmailConfirmError: Error {
    case ioError(Error)
    case serverError
    case unauthorized
    case invalidOrExpiredCode
  }

  public enum EmailUnlinkError: Error {
    case ioError(Error)
    case serverError
    case unauthorized
  }
}
