import CommunityDraftService
import CommunityDraftStorageService
import Foundation

struct CommunityDraftStorageServiceLive: Sendable {
  private let postStore = CommunityDraftStore(
    directory: URL.applicationSupportDirectory.appending(path: "CommunityDrafts", directoryHint: .isDirectory)
  )

  func loadPost(_ key: CommunityDraftStorageService.Key) async throws -> String? {
    try await store(for: key).load(accountID: key.accountID, sessionID: key.sessionID)
  }

  func postDraftUpdates(_ key: CommunityDraftStorageService.Key) async throws -> AsyncStream<String?> {
    try await postStore.updates(accountID: key.accountID, sessionID: key.sessionID)
  }

  func savePost(_ key: CommunityDraftStorageService.Key, _ text: String) async throws {
    try await store(for: key).save(text, accountID: key.accountID, sessionID: key.sessionID)
  }

  func loadReply(_ key: CommunityDraftStorageService.Key) async throws -> CommunityReplyDraft? {
    try await store(for: key).loadReply(accountID: key.accountID, sessionID: key.sessionID)
  }

  func saveReply(_ key: CommunityDraftStorageService.Key, _ content: CommunityReplyDraft) async throws {
    try await store(for: key).saveReply(content, accountID: key.accountID, sessionID: key.sessionID)
  }

  func remove(_ key: CommunityDraftStorageService.Key) async throws {
    try await store(for: key).remove(accountID: key.accountID, sessionID: key.sessionID)
  }

  func revokePost(_ key: CommunityDraftStorageService.Key) async throws {
    try await postStore.revoke(accountID: key.accountID, sessionID: key.sessionID)
  }
}

private extension CommunityDraftStorageServiceLive {
  private func store(for key: CommunityDraftStorageService.Key) -> CommunityDraftStore {
    guard let parentID = key.parentID else { return postStore }
    return CommunityDraftStore(
      directory: URL.applicationSupportDirectory
        .appending(path: "CommunityDrafts/Replies", directoryHint: .isDirectory)
        .appending(component: String(parentID))
    )
  }
}
