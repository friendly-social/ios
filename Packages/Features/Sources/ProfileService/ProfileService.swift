import CommunityMarkdownService
import DependenciesMacros
import Models

@DependencyClient
public struct ProfileService: Sendable {
  public var prepareDescription: @Sendable (String) async -> MarkdownDocument? = { _ in nil }
  public var loadProfile: @Sendable (ProfileSelection) async throws -> LoadedProfile?
  public var loadFriends: @Sendable () async throws -> [FriendSummary]?
  public var requestFriend: @Sendable (UserId, UserAccessHash) async throws -> Void
  public var declineFriend: @Sendable (UserId, UserAccessHash) async throws -> Void
  public var signOut: @Sendable () -> Void
}

public enum ProfileSelection {
  case current
  case other(id: UserId, accessHash: UserAccessHash)
}

public struct LoadedProfile: Sendable {
  public enum Relationship: Sendable {
    case own
    case other(friendship: Friendship, commonFriends: [FriendSummary])
  }

  public let info: ProfileInfo
  public let relationship: Relationship

  public init(info: ProfileInfo, relationship: Relationship) {
    self.info = info
    self.relationship = relationship
  }

  public var commonFriends: [FriendSummary]? {
    guard case let .other(_, friends) = relationship else { return nil }
    return friends
  }
}
