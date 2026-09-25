import CommunityDraftService
import CommunityDraftStorageService
import CommunityMarkdownService
import CommunityService
import Dependencies
import Foundation

struct CommunityDraftServiceLive: Sendable {
  @Dependency(CommunityDraftStorageService.self) private var storage

  func postDraftUpdates(_ accountID: Int64, _ sessionID: String) async throws -> AsyncStream<String?> {
    let updates = try await storage.postDraftUpdates(.init(accountID: accountID, sessionID: sessionID))
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let task = Task {
        for await source in updates {
          guard !Task.isCancelled else { break }
          continuation.yield(source.flatMap {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
          })
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  func postDrafts(
    _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    drafts(key: .init(accountID: accountID, sessionID: sessionID), isCurrentSession: isCurrentSession)
  }

  func replyDrafts(
    _ parent: PostDescriptor, _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    drafts(
      key: .init(accountID: accountID, sessionID: sessionID, parentID: parent.id),
      isCurrentSession: isCurrentSession
    )
  }

  func detailDrafts(
    _ parent: PostDescriptor, _ accountID: Int64, _ sessionID: String,
    _ isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityReplyDrafts {
    let key = CommunityDraftStorageService.Key(
      accountID: accountID, sessionID: sessionID, parentID: parent.id
    )
    return CommunityReplyDrafts(
      load: {
        guard isCurrentSession() else { throw CancellationError() }
        guard let stored = try await self.storage.loadReply(key) else { return nil }
        return self.normalized(stored)
      },
      save: { content in
        guard isCurrentSession() else { throw CancellationError() }
        try await self.storage.saveReply(key, self.normalized(content))
      },
      remove: { try await self.storage.remove(key) }
    )
  }

  func revokePostDrafts(_ accountID: Int64, _ sessionID: String) async throws {
    try await storage.revokePost(.init(accountID: accountID, sessionID: sessionID))
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
    key: CommunityDraftStorageService.Key,
    isCurrentSession: @escaping @Sendable () -> Bool
  ) -> CommunityDrafts {
    CommunityDrafts(
      load: {
        guard isCurrentSession() else { throw CancellationError() }
        return try await self.storage.loadPost(key)
      },
      save: { text in
        guard isCurrentSession() else { throw CancellationError() }
        try await self.storage.savePost(key, text)
      },
      remove: { try await self.storage.remove(key) }
    )
  }
}
