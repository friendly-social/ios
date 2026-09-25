import AccountSessionService
import AccountStorageService
import CommunityProfileService
import CommunityService
import Dependencies
import FilesApi
import Foundation
import Models
import ProfileApi

struct CommunityProfileServiceLive: Sendable {
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(AccountSessionService.self) private var accountSession
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(ProfileApi.self) private var profileApi

  func currentSession() -> CommunitySession? {
    guard let authorization = try? storage.loadAuthorization() else { return nil }
    return .init(
      accountID: authorization.id.int64, token: authorization.token.string,
      sessionID: CommunitySessionKey.make(authorization.token.string))
  }

  func isCurrentSession(_ session: CommunitySession) -> Bool {
    guard let current = currentSession() else { return false }
    return current.accountID == session.accountID && current.token == session.token
  }

  func cachedOwner(_ session: CommunitySession) -> CommunityPost.Owner? {
    (try? storage.loadCommunityProfile(session.accountID)).map(communityOwner(from:))
  }

  func loadOwner(_ session: CommunitySession) async throws -> CommunityPost.Owner {
    guard isCurrentSession(session),
          let authorization = try? storage.loadAuthorization() else {
      throw CommunityError.unauthorized
    }
    do {
      let user = try await profileApi.usersDetails(
        authorization, authorization.id, authorization.accessHash)
      guard isCurrentSession(session) else { throw CancellationError() }
      let owner = CommunityPost.Owner(
        id: user.id.int64, accessHash: user.accessHash.string, nickname: user.nickname.string,
        avatar: user.avatar.map { .init(id: $0.id.int64, accessHash: $0.accessHash.string) })
      try? storage.saveCommunityProfile(cachedProfile(from: owner))
      return owner
    } catch {
      if case ProfileApi.UserDetailsError.unauthorized = error {
        throw CommunityError.unauthorized
      }
      throw error
    }
  }

  func avatarURL(_ avatar: CommunityPost.Owner.Avatar) -> URL {
    filesApi.downloadURL(.init(id: avatar.id, accessHash: avatar.accessHash))
  }

  func clearSession() { accountSession.clearAuthorization() }
}

private extension CommunityProfileServiceLive {
  private func cachedProfile(from owner: CommunityPost.Owner) -> CachedAccountProfile {
    CachedAccountProfile(
      id: owner.id,
      accessHash: owner.accessHash,
      nickname: owner.nickname,
      avatarID: owner.avatar?.id,
      avatarAccessHash: owner.avatar?.accessHash
    )
  }

  private func communityOwner(from profile: CachedAccountProfile) -> CommunityPost.Owner {
    let avatar = profile.avatarID.flatMap { id in
      profile.avatarAccessHash.map { CommunityPost.Owner.Avatar(id: id, accessHash: $0) }
    }
    return .init(
      id: profile.id, accessHash: profile.accessHash,
      nickname: profile.nickname, avatar: avatar
    )
  }
}
