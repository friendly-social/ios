import CommunityService
import Foundation
import SwiftUI

struct CommunityPostCard: View {
  let post: CommunityPost
  let content: CommunityFeedPost.Content
  let avatarURL: (CommunityPost.Owner.Avatar) -> URL
  let openAuthor: ((CommunityPost.Owner) -> Void)?
  let canManage: Bool
  let isDeleting: Bool
  let actionsDisabled: Bool
  let edit: () -> Void
  let delete: () -> Void
  let reply: () -> Void
  let openDetails: () -> Void

  var body: some View {
    contentView()
  }
}

private extension CommunityPostCard {

  @ViewBuilder
  private func contentView() -> some View {
    HStack(alignment: .top, spacing: Constants.columnSpacing) {
      avatarButton()
        .buttonStyle(.plain)
        .disabled(post.owner == nil || openAuthor == nil)
        .accessibilityLabel(
          authorAccessibilityLabel())
      postColumnView()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, Constants.horizontalPadding)
    .padding(.top, Constants.topPadding)
    .padding(.bottom, Constants.bottomPadding)
    .contentShape(.rect)
    // Keep the card's links, author and menu independently interactive.
    .onTapGesture(perform: openDetails)
    .accessibilityAction(named: .postReadAll, openDetails)
  }



  private func authorAccessibilityLabel() -> Text {
    if let owner = post.owner { return Text(.postProfile(owner.nickname)) }
    return Text(.postAuthor)
  }

  @ViewBuilder
  private func avatarButton() -> some View {
    Button {
      if let owner = post.owner { openAuthor?(owner) }
    } label: {
      CommunityAvatar(owner: post.owner, avatarURL: avatarURL)
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
    }
  }

  @ViewBuilder
  private func postBodyView() -> some View {
    VStack(alignment: .leading, spacing: Constants.headerSpacing) {
      CommunityPostHeader(
        post: post, openAuthor: openAuthor,
        canManage: canManage, isDeleting: isDeleting, actionsDisabled: actionsDisabled,
        edit: edit, delete: delete
      )
      CommunityPostContent(content: content, expandsInPlace: false, openDetails: openDetails)
    }
  }

  @ViewBuilder
  private func postColumnView() -> some View {
    VStack(alignment: .leading, spacing: Constants.footerSpacing) {
      postBodyView()
      CommunityPostFooter(
        owners: post.replyPreviews, avatarURL: avatarURL,
        reply: reply, openDetails: openDetails)
        .disabled(actionsDisabled)
    }
  }
}

private enum Constants {
  static let columnSpacing: CGFloat = 10
  static let headerSpacing: CGFloat = 4
  // The footer's 44 pt hit target already provides space around its label.
  static let footerSpacing: CGFloat = 0
  static let avatarSize: CGFloat = 40
  static let horizontalPadding: CGFloat = 16
  static let topPadding: CGFloat = 12
  static let bottomPadding: CGFloat = 8
}
