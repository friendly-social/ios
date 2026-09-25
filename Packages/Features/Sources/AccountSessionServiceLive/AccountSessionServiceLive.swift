import AccountStorageService
import CommunityDraftService
import Dependencies
import Models

struct AccountSessionServiceLive: Sendable {
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(CommunityDraftService.self) private var drafts

  func clearAuthorization() {
    let authorization = try? storage.loadAuthorization()
    storage.clearAuthorization()
    guard let authorization else { return }
    let accountID = authorization.id.int64
    let sessionID = CommunitySessionKey.make(authorization.token.string)
    Task { try? await drafts.revokePostDrafts(accountID, sessionID) }
  }
}
