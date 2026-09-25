import DependenciesMacros
import Models

@DependencyClient
public struct FriendsApi: Sendable {
  public var networkDetails: @Sendable (Authorization) async throws -> NetworkDetails
  public var friendsGenerate: @Sendable (Authorization) async throws -> FriendToken
  public var friendsAdd: @Sendable (Authorization, FriendToken, UserId) async throws -> Void
  public var friendsDecline: @Sendable (Authorization, UserId, UserAccessHash) async throws -> Void
  public var friendsRequest: @Sendable (Authorization, UserId, UserAccessHash) async throws -> Void

  public enum Error: Swift.Error {
    case ioError(Swift.Error)
    case serverError(statusCode: Int)
    case unauthorized
    case expiredToken
  }
}
