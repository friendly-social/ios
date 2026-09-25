import CommunityService
import Foundation
import FriendlyUIKit
import SwiftUI

struct CommunityPostHeader: View {
  let post: CommunityPost
  let openAuthor: ((CommunityPost.Owner) -> Void)?
  let canManage: Bool
  let isDeleting: Bool
  let actionsDisabled: Bool
  let edit: () -> Void
  let delete: () -> Void

  var body: some View {
    contentView()
  }
}

private extension CommunityPostHeader {

  @ViewBuilder
  private func contentView() -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
      metadataView()
      Spacer(minLength: Constants.zero)
      if isDeleting {
        ProgressView().accessibilityLabel(
          .postDeleting)
      } else if canManage {
        actionsMenu()
          .padding(.vertical, -Constants.menuInset)
          .disabled(actionsDisabled)
          .accessibilityLabel(
            .postActions)
      }
    }
  }

  @ViewBuilder private func author() -> some View {
    if let owner = post.owner, let openAuthor {
      Button {
        openAuthor(owner)
      } label: {
        authorLabel()
      }
      .buttonStyle(.plain)
      .accessibilityHint(
        .postAuthorHint)
    } else {
      authorLabel()
    }
  }

  private func authorLabel() -> some View {
    authorText()
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(Constants.primary)
    .multilineTextAlignment(.leading)
  }

  private func authorText() -> Text {
    if let owner = post.owner { return Text(owner.nickname) }
    return Text(post.text == nil ? .postDeletedAuthor : .postYou)
  }

  @ViewBuilder private func timestamp() -> some View {
    if let date = post.date {
      TimelineView(.periodic(from: .now, by: Constants.dateRefreshInterval)) { _ in
        timestampText(for: date)
          .font(.caption)
          .foregroundStyle(Constants.secondary)
          .accessibilityLabel(date.formatted(date: .complete, time: .shortened))
      }
    }
    if post.edited {
      Image(systemName: Constants.edited)
        .font(.caption)
        .foregroundStyle(Constants.secondary)
        .accessibilityLabel(
          .postEdited)
    }
  }

  private func timestampText(for date: Date) -> Text {
    if Date.now.timeIntervalSince(date) < Constants.dateRefreshInterval {
      return Text(.postNow)
    }
    return Text(date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
  }

  @ViewBuilder
  private func actionsMenu() -> some View {
    MenuButton(
      systemImage: Constants.menu, accessibilityLabel: .postActions,
      items: [
        .action(title: .postEdit, systemImage: Constants.edit, action: { edit() }),
        .submenu(
          title: .postDelete, message: .postDeleteMessage,
          systemImage: Constants.delete, role: .destructive,
          items: [
            .action(title: .postDeleteAction, systemImage: Constants.delete,
              role: .destructive, action: { delete() })
          ])
      ])
      .frame(width: Constants.touchTarget, height: Constants.touchTarget)
  }

  @ViewBuilder
  private func metadataView() -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
        author()
        timestamp()
      }
      VStack(alignment: .leading, spacing: Constants.compactSpacing) {
        author()
        timestamp()
      }
    }
  }
}

private enum Constants {
  static let zero: CGFloat = 0
  static let spacing: CGFloat = 6
  static let compactSpacing: CGFloat = 2
  static let touchTarget: CGFloat = 44
  static let menuInset: CGFloat = 12
  static let dateRefreshInterval: TimeInterval = 60
  static let primary = Color.primary
  static let secondary = Color.secondary
  static let edit = "pencil"
  static let edited = "pencil.line"
  static let delete = "trash"
  static let menu = "ellipsis"
}
