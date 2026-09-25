import DependenciesMacros
import Models

@DependencyClient
public struct ProfileApi: Sendable {
  public var usersDetails: @Sendable (Authorization, UserId, UserAccessHash) async throws -> UserDetails
  public var usersEdit: @Sendable (Authorization, Nickname, UserDescription, [Interest], FileDescriptor?, SocialLink?) async throws -> Void

  public enum UserDetailsError: Error {
    case ioError(Error)
    case serverError
    case unauthorized
  }
}
