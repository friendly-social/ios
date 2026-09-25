import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct DiscoveryFeedService: Sendable {
  public var loadCandidates: @Sendable () async throws -> [DiscoveryCandidate]
  public var requestFriend: @Sendable (UserId, UserAccessHash) async throws -> Void
  public var declineFriend: @Sendable (UserId, UserAccessHash) async throws -> Void
}

public struct DiscoveryCandidate {
  public let id: UserId
  public let accessHash: UserAccessHash
  public let avatarURL: URL?
  public let nickname: Nickname
  public let description: UserDescription
  public let interests: [Interest]
  public let commonFriends: [DiscoveryCommonFriend]
  public let isRequest: Bool
  public let isExtendedNetwork: Bool

  public init(
    id: UserId, accessHash: UserAccessHash, avatarURL: URL?, nickname: Nickname,
    description: UserDescription, interests: [Interest], commonFriends: [DiscoveryCommonFriend],
    isRequest: Bool, isExtendedNetwork: Bool
  ) {
    self.id = id
    self.accessHash = accessHash
    self.avatarURL = avatarURL
    self.nickname = nickname
    self.description = description
    self.interests = interests
    self.commonFriends = commonFriends
    self.isRequest = isRequest
    self.isExtendedNetwork = isExtendedNetwork
  }
}

public struct DiscoveryCommonFriend {
  public let id: UserId
  public let accessHash: UserAccessHash
  public let avatarURL: URL

  public init(id: UserId, accessHash: UserAccessHash, avatarURL: URL) {
    self.id = id
    self.accessHash = accessHash
    self.avatarURL = avatarURL
  }
}
