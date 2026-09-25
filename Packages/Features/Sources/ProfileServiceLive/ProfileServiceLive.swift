import AccountStorageService
import AccountSessionService
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

  func loadProfile(_ selection: ProfileSelection) async throws -> ProfileInfo? {
    let authorization = try storage.loadAuthorization()
    let (id, accessHash) = profileIdentifier(for: selection, authorization: authorization)
    let details = try await profileApi.usersDetails(authorization, id, accessHash)
    try Task.checkCancellation()
    let current = try storage.loadAuthorization()
    guard current.id == authorization.id, current.token == authorization.token else {
      return nil
    }
    return ProfileInfo(
      avatarUrl: details.avatar.map { filesApi.downloadURL(for: $0) },
      nickname: details.nickname,
      description: details.description,
      interests: details.interests,
      socialUrl: details.socialLink.flatMap { URL(string: $0.string) },
      email: details.email
    )
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
