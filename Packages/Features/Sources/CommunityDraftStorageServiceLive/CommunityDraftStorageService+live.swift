import CommunityDraftStorageService
import Dependencies

extension CommunityDraftStorageService: DependencyKey {
  public static var liveValue: Self {
    let live = CommunityDraftStorageServiceLive()
    return .init(
      postDraftUpdates: { try await live.postDraftUpdates($0) },
      loadPost: { key in try await live.loadPost(key) },
      savePost: { key, text in try await live.savePost(key, text) },
      loadReply: { key in try await live.loadReply(key) },
      saveReply: { key, content in try await live.saveReply(key, content) },
      remove: { key in try await live.remove(key) },
      revokePost: { key in try await live.revokePost(key) }
    )
  }
}
