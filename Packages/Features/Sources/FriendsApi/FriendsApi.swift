import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct FriendsApi: Sendable {
  public var networkDetails: @Sendable (Authorization) async throws -> NetworkDetails
  public var friendsGenerate: @Sendable (Authorization, Bool) async throws -> FriendInvitation
  public var friendsAdd: @Sendable (Authorization, FriendToken) async throws -> Void
  public var friendsDecline: @Sendable (Authorization, UserId, UserAccessHash) async throws -> Void
  public var friendsRequest: @Sendable (Authorization, UserId, UserAccessHash) async throws -> Void

  public enum Error: Swift.Error {
    case ioError(Swift.Error)
    case serverError(statusCode: Int)
    case unauthorized
    case expiredToken
  }
}

public struct FriendInvitation: Sendable {
  public let token: FriendToken
  public let expiration: Date

  public init(token: FriendToken, expiration: Date) {
    self.token = token
    self.expiration = expiration
  }
}
