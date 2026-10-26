import ActivityService
import Foundation
import FriendlyUIKit
import SwiftUI

struct ActivityRowView: View {
  let event: ActivityEvent
  let avatarURL: URL?

  var body: some View { contentView() }
}

private extension ActivityRowView {
  private func contentView() -> some View {
    HStack(alignment: .top, spacing: Constants.spacing) {
      AvatarView(url: avatarURL, size: Constants.avatarSize).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Constants.textSpacing) {
        Text(.activityReplyFrom(event.reply.owner?.nickname ?? ""))
          .font(.subheadline.weight(.semibold))
        Text(event.preview).font(.subheadline).foregroundStyle(.secondary)
          .lineLimit(Constants.previewLines)
        HStack(spacing: Constants.textSpacing) {
          if !event.isRead { unreadIndicator() }
          Text(event.date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, Constants.verticalPadding)
    .accessibilityElement(children: .combine)
    .accessibilityHint(.activityOpenHint)
  }

  private func unreadIndicator() -> some View {
    Circle().fill(Color.accentColor)
      .frame(width: Constants.dotSize, height: Constants.dotSize)
      .accessibilityLabel(.activityUnread)
  }
}

private enum Constants {
  static let spacing: CGFloat = 12
  static let textSpacing: CGFloat = 6
  static let avatarSize: CGFloat = 40
  static let verticalPadding: CGFloat = 4
  static let dotSize: CGFloat = 7
  static let previewLines = 2
}
