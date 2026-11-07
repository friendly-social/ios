import CommunityMarkdownFeature
import CommunityService
import SwiftUI

@MainActor
public struct CommunityDiscussionView: View {
  @State private var model: CommunityPostDetailViewModel
  @State private var imageLayoutCache = MarkdownImageLayoutCache()
  private let highlightedReplyID: Int64?

  public init(
    details: CommunityPostDetails, highlightedReplyID: Int64? = nil,
    onUnauthorized: @escaping () -> Void
  ) {
    _model = State(initialValue: CommunityPostDetailViewModel(
      post: details.post, initialDetails: details,
      focusedReply: details.replies.data.compactMap(\.directPost)
        .first(where: { $0.id == highlightedReplyID })?.descriptor,
      onUnauthorized: onUnauthorized))
    self.highlightedReplyID = highlightedReplyID
  }

  public var body: some View { contentView() }
}

private extension CommunityDiscussionView {
  private func contentView() -> some View {
    CommunityPostDetailView(
      model: model, currentUser: model.currentOwner, avatarURL: model.avatarURL,
      initialReplyID: highlightedReplyID)
      .markdownImageLayoutCache(imageLayoutCache)
  }
}
