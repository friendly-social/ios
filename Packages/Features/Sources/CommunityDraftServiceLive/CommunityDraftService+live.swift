import CommunityDraftService
import Dependencies

extension CommunityDraftService {
  public static func live() -> Self {
    let live = CommunityDraftServiceLive()
    return .init(
      postDraftUpdates: { try await live.postDraftUpdates($0, $1) },
      postDrafts: { live.postDrafts($0, $1, $2) },
      replyDrafts: { live.replyDrafts($0, $1, $2, $3) },
      detailDrafts: { live.detailDrafts($0, $1, $2, $3) },
      replyDraft: { live.replyDraft($0) },
      revokePostDrafts: { try await live.revokePostDrafts($0, $1) }
    )
  }
}

extension CommunityDraftService: DependencyKey {
  public static var liveValue: Self { .live() }
}
