import AccountStorageService
import Dependencies
import DiscoveryFeedService
import FeedApi
import FilesApi
import FriendsApi
import Models

struct DiscoveryFeedServiceLive: Sendable {
  @Dependency(FeedApi.self) private var feedApi
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(FriendsApi.self) private var friendsApi
  @Dependency(AccountStorageService.self) private var storage

  func loadCandidates() async throws -> [DiscoveryCandidate] {
    let authorization = try storage.loadAuthorization()
    let queue = try await feedApi.queue(authorization)
    return queue.entries.map { entry in
      DiscoveryCandidate(
        id: entry.details.id,
        accessHash: entry.details.accessHash,
        avatarURL: entry.details.avatar.map { filesApi.downloadURL(for: $0) },
        nickname: entry.details.nickname,
        description: entry.details.description,
        interests: entry.details.interests,
        commonFriends: commonFriends(for: entry),
        isRequest: entry.isRequest,
        isExtendedNetwork: entry.isExtendedNetwork
      )
    }
  }

  func requestFriend(id: UserId, accessHash: UserAccessHash) async throws {
    let authorization = try storage.loadAuthorization()
    try await friendsApi.friendsRequest(authorization, id, accessHash)
  }

  func declineFriend(id: UserId, accessHash: UserAccessHash) async throws {
    let authorization = try storage.loadAuthorization()
    try await friendsApi.friendsDecline(authorization, id, accessHash)
  }
}

private extension DiscoveryFeedServiceLive {
  private func commonFriends(for entry: FeedQueue.Entry) -> [FriendSummary] {
    entry.commonFriends.map { friend in
      .init(
        id: friend.id,
        accessHash: friend.accessHash,
        nickname: friend.nickname,
        avatarURL: friend.avatar.map { filesApi.downloadURL(for: $0) }
      )
    }
  }
}
