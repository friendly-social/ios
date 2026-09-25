
import DependenciesMacros

@DependencyClient
public struct EmailAuthService: Sendable {
  public var requestBindingCode: @Sendable (String) async throws -> Void
  public var confirmBinding: @Sendable (Int) async throws -> Void
  public var requestLoginCode: @Sendable (String) async throws -> Void
  public var login: @Sendable (String, Int) async throws -> Void
}

public enum EmailAuthError: Error {
  case alreadyUsed
  case unauthorized
  case unknownEmail
  case invalidCode
  case networkError
}
