import AccountStorageService
import CommunityDraftService
import Dependencies
import Models
import PushRegistrationService

struct AccountSessionServiceLive: Sendable {
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(CommunityDraftService.self) private var drafts
  @Dependency(PushRegistrationService.self) private var pushRegistration

  func clearAuthorization() {
    let authorization = try? storage.loadAuthorization()
    storage.clearAuthorization()
    pushRegistration.refresh()
    guard let authorization else { return }
    let accountID = authorization.id.int64
    let sessionID = CommunitySessionKey.make(authorization.token.string)
    Task { try? await drafts.revokePostDrafts(accountID, sessionID) }
  }
}
