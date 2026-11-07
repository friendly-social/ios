import DependenciesMacros
import Models

@DependencyClient
public struct ProfileApi: Sendable {
  public var usersDetails: @Sendable (Authorization, UserId, UserAccessHash) async throws -> UserDetails
  public var usersDetailsWithFriends: @Sendable (Authorization, UserId, UserAccessHash) async throws -> ProfileDetails
  public var usersEdit: @Sendable (Authorization, Nickname, UserDescription, [Interest], FileDescriptor?, SocialLink?) async throws -> Void

  public enum UserDetailsError: Error {
    case ioError(Error)
    case serverError
    case unauthorized
  }
}

public struct ProfileDetails: Sendable {
  public let user: UserDetails
  public let friendship: Friendship
  public let commonFriends: [UserDetails]

  public init(user: UserDetails, friendship: Friendship, commonFriends: [UserDetails]) {
    self.user = user
    self.friendship = friendship
    self.commonFriends = commonFriends
  }
}
