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
  let translation: CommunityPostTranslationViewModel?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .subheadline) private var translationWidth = Constants.translationWidth

  init(
    post: CommunityPost, openAuthor: ((CommunityPost.Owner) -> Void)?,
    canManage: Bool, isDeleting: Bool, actionsDisabled: Bool,
    edit: @escaping () -> Void, delete: @escaping () -> Void,
    translation: CommunityPostTranslationViewModel? = nil
  ) {
    self.post = post
    self.openAuthor = openAuthor
    self.canManage = canManage
    self.isDeleting = isDeleting
    self.actionsDisabled = actionsDisabled
    self.edit = edit
    self.delete = delete
    self.translation = translation
  }

  var body: some View {
    contentView()
  }
}

private extension CommunityPostHeader {

  @ViewBuilder
  private func contentView() -> some View {
    metadataView()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.trailing, controlsWidth)
      .overlay(alignment: controlsAlignment) { controlsView() }
  }

  private var controlsAlignment: Alignment {
    if canManage || isDeleting { return .trailing }
    return Alignment(horizontal: .trailing, vertical: .firstTextBaseline)
  }

  private var controlsWidth: CGFloat {
    if canManage || isDeleting { return Constants.touchTarget + Constants.spacing }
    return translation == nil ? Constants.zero : translationWidth + Constants.spacing
  }

  @ViewBuilder
  private func controlsView() -> some View {
    if isDeleting {
      ProgressView()
        .frame(width: Constants.touchTarget, height: Constants.touchTarget)
        .accessibilityLabel(.postDeleting)
    } else if canManage {
      actionsMenu()
        .disabled(actionsDisabled)
        .accessibilityLabel(.postActions)
    } else if let translation, translation.languageLabel != nil {
      CommunityPostTranslationButton(model: translation, alignment: .trailing)
        .frame(width: translationWidth, alignment: .trailing)
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
    .lineLimit(1)
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
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: Constants.compactSpacing) {
        author()
        timestamp()
      }
    } else {
      HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
        author()
        timestamp()
          .fixedSize()
      }
    }
  }
}

private enum Constants {
  static let zero: CGFloat = 0
  static let spacing: CGFloat = 6
  static let compactSpacing: CGFloat = 2
  static let touchTarget: CGFloat = 44
  static let translationWidth: CGFloat = 48
  static let dateRefreshInterval: TimeInterval = 60
  static let primary = Color.primary
  static let secondary = Color.secondary
  static let edit = "pencil"
  static let edited = "pencil.line"
  static let delete = "trash"
  static let menu = "ellipsis"
}
