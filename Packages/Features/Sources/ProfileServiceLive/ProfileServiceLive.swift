import AccountSessionService
import AccountStorageService
import Dependencies
import FilesApi
import Foundation
import FriendsApi
import Models
import ProfileApi
import ProfileService

struct ProfileServiceLive: Sendable {
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(FriendsApi.self) private var friendsApi
  @Dependency(ProfileApi.self) private var profileApi
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(AccountSessionService.self) private var accountSession

  func loadProfile(_ selection: ProfileSelection) async throws -> LoadedProfile? {
    let authorization = try storage.loadAuthorization()
    let (id, accessHash) = profileIdentifier(for: selection, authorization: authorization)
    let details = try await profileApi.usersDetailsWithFriends(authorization, id, accessHash)
    try Task.checkCancellation()
    let current = try storage.loadAuthorization()
    guard current.id == authorization.id, current.token == authorization.token else { return nil }
    let user = details.user
    let info = ProfileInfo(
      avatarUrl: user.avatar.map { filesApi.downloadURL(for: $0) }, nickname: user.nickname,
      description: user.description, interests: user.interests,
      socialUrl: user.socialLink.flatMap { URL(string: $0.string) }, email: user.email)
    return LoadedProfile(info: info, relationship: relationship(for: selection, details: details))
  }

  func loadFriends() async throws -> [FriendSummary]? {
    let authorization = try storage.loadAuthorization()
    let details = try await friendsApi.networkDetails(authorization)
    try Task.checkCancellation()
    let current = try storage.loadAuthorization()
    guard current.id == authorization.id, current.token == authorization.token else { return nil }
    return details.friends.map(friendSummary)
  }

  func requestFriend(id: UserId, accessHash: UserAccessHash) async throws {
    let authorization = try storage.loadAuthorization()
    try await friendsApi.friendsRequest(authorization, id, accessHash)
  }

  func declineFriend(id: UserId, accessHash: UserAccessHash) async throws {
    let authorization = try storage.loadAuthorization()
    try await friendsApi.friendsDecline(authorization, id, accessHash)
  }

  func signOut() {
    accountSession.clearAuthorization()
  }
}

private extension ProfileServiceLive {
  private func relationship(for selection: ProfileSelection, details: ProfileDetails) -> LoadedProfile.Relationship {
    guard case .other = selection else { return .own }
    return .other(friendship: details.friendship, commonFriends: details.commonFriends.map(friendSummary))
  }

  private func friendSummary(_ user: UserDetails) -> FriendSummary {
    .init(
      id: user.id,
      accessHash: user.accessHash,
      nickname: user.nickname,
      avatarURL: user.avatar.map { filesApi.downloadURL(for: $0) }
    )
  }

  private func profileIdentifier(
    for selection: ProfileSelection,
    authorization: Authorization
  ) -> (UserId, UserAccessHash) {
    switch selection {
    case .current: (authorization.id, authorization.accessHash)
    case let .other(id, accessHash): (id, accessHash)
    }
  }
}
