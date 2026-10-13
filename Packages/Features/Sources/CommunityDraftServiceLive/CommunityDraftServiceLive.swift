import CommunityDraftService
import CommunityMarkdownService
import CommunityService
import Foundation

struct CommunityDraftServiceLive: Sendable {
  private let directory: URL
  private let postStore: CommunityDraftStore

  init(directory: URL = URL.applicationSupportDirectory.appending(path: "CommunityDrafts", directoryHint: .isDirectory)) {
    self.directory = directory
    postStore = CommunityDraftStore(directory: directory)
  }

  func postDraftUpdates(_ accountID: Int64, _ sessionID: String) async throws -> AsyncStream<String?> {
    try await postStore.updates(accountID: accountID, sessionID: sessionID)
  }

  func postDrafts(
    _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    drafts(store: postStore, accountID: accountID, sessionID: sessionID, isCurrentSession: isCurrentSession)
  }

  func replyDrafts(
    _ parent: PostDescriptor, _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    drafts(
      store: replyStore(parent), accountID: accountID, sessionID: sessionID,
      isCurrentSession: isCurrentSession
    )
  }

  func detailDrafts(
    _ parent: PostDescriptor, _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityReplyDrafts {
    let store = replyStore(parent)
    return CommunityReplyDrafts(
      load: {
        guard isCurrentSession() else { throw CancellationError() }
        guard let stored = try await store.loadReply(accountID: accountID, sessionID: sessionID) else { return nil }
        return self.normalized(stored)
      },
      save: { content in
        guard isCurrentSession() else { throw CancellationError() }
        try await store.saveReply(self.normalized(content), accountID: accountID, sessionID: sessionID)
      },
      remove: { try await store.remove(accountID: accountID, sessionID: sessionID) }
    )
  }

  func revokePostDrafts(_ accountID: Int64, _ sessionID: String) async throws {
    try await postStore.revoke(accountID: accountID, sessionID: sessionID)
  }

  func replyDraft(_ source: String) -> CommunityReplyDraft {
    guard !source.isEmpty else { return .plainText("") }
    let codec = MarkdownCodec()
    guard !codec.requiresSourceEditing(source),
          let rendered = try? codec.decode(source),
          rendered.runs.allSatisfy({ ($0.inlinePresentationIntent ?? []).isEmpty && $0.link == nil })
    else { return .markdown(source) }
    return .plainText(String(rendered.characters))
  }
}

private extension CommunityDraftServiceLive {
  private func normalized(_ draft: CommunityReplyDraft) -> CommunityReplyDraft {
    guard case let .markdown(source) = draft else { return draft }
    return replyDraft(source)
  }

  private func drafts(
    store: CommunityDraftStore, accountID: Int64, sessionID: String,
    isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    CommunityDrafts(
      load: {
        guard isCurrentSession() else { throw CancellationError() }
        return try await store.load(accountID: accountID, sessionID: sessionID)
      },
      save: { text in
        guard isCurrentSession() else { throw CancellationError() }
        try await store.save(text, accountID: accountID, sessionID: sessionID)
      },
      remove: { try await store.remove(accountID: accountID, sessionID: sessionID) }
    )
  }

  private func replyStore(_ parent: PostDescriptor) -> CommunityDraftStore {
    CommunityDraftStore(directory: directory.appending(path: "Replies", directoryHint: .isDirectory)
      .appending(component: String(parent.id)))
  }
}
