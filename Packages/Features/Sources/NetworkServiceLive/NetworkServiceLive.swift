import AccountStorageService
import Dependencies
import FilesApi
import FriendsApi
import NetworkService

struct NetworkServiceLive: Sendable {
  @Dependency(FriendsApi.self) private var friendsApi
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(AccountStorageService.self) private var storage

  func loadFriends() async throws -> [NetworkFriend] {
    let authorization = try storage.loadAuthorization()
    let details = try await friendsApi.networkDetails(authorization)
    return details.friends.map { friend in
      NetworkFriend(
        id: friend.id,
        accessHash: friend.accessHash,
        avatarURL: friend.avatar.map { filesApi.downloadURL(for: $0) },
        nickname: friend.nickname
      )
    }
  }
}
