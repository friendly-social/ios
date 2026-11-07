import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct NetworkService: Sendable {
  public var loadFriends: @Sendable () async throws -> [NetworkFriend]
}

public struct NetworkFriend {
  public let id: UserId
  public let accessHash: UserAccessHash
  public let avatarURL: URL?
  public let nickname: Nickname

  public init(id: UserId, accessHash: UserAccessHash, avatarURL: URL?, nickname: Nickname) {
    self.id = id
    self.accessHash = accessHash
    self.avatarURL = avatarURL
    self.nickname = nickname
  }
}
