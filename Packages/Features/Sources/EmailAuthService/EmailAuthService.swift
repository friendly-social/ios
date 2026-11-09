
import DependenciesMacros

@DependencyClient
public struct EmailAuthService: Sendable {
  public var requestBindingCode: @Sendable (_ email: String) async throws -> Void
  public var confirmBinding: @Sendable (
    _ email: String,
    _ code: Int
  ) async throws -> Void
  public var requestLoginCode: @Sendable (_ email: String) async throws -> Void
  public var login: @Sendable (
    _ email: String,
    _ code: Int
  ) async throws -> Void
}

public enum EmailAuthError: Error {
  case alreadyUsed
  case unauthorized
  case unknownEmail
  case invalidCode
  case networkError
}
