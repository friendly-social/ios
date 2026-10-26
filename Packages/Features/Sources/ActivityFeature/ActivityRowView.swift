import ActivityService
import Foundation
import FriendlyUIKit
import SwiftUI

struct ActivityRowView: View {
  let event: ActivityEvent
  let avatarURL: URL?
  @ScaledMetric(relativeTo: .subheadline) private var avatarSize = Constants.avatarSize
  @ScaledMetric(relativeTo: .caption) private var badgeSize = Constants.badgeSize
  @ScaledMetric(relativeTo: .caption) private var symbolSize = Constants.symbolSize

  var body: some View { contentView() }
}

private extension ActivityRowView {
  private func contentView() -> some View {
    HStack(alignment: .top, spacing: Constants.spacing) {
      avatarView()
      VStack(alignment: .leading, spacing: Constants.textSpacing) {
        Text(title).font(.subheadline.weight(.semibold))
        if !event.preview.isEmpty {
          Text(event.preview).font(.subheadline).foregroundStyle(.secondary)
            .lineLimit(Constants.previewLines)
        }
        timestampView()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, Constants.verticalPadding)
    .accessibilityElement(children: .combine)
    .accessibilityHint(openHint)
  }

  private func avatarView() -> some View {
    AvatarView(url: avatarURL, size: avatarSize)
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: symbol)
          .font(.system(size: symbolSize, weight: .semibold))
          .foregroundStyle(symbolColor)
          .frame(width: badgeSize, height: badgeSize)
          .background(Constants.badgeBackground, in: .circle)
          .overlay { Circle().strokeBorder(.secondary.opacity(Constants.borderOpacity)) }
          .offset(x: Constants.badgeOffset, y: Constants.badgeOffset)
      }
      .padding([.trailing, .bottom], Constants.badgeOffset)
      .accessibilityHidden(true)
  }

  private func timestampView() -> some View {
    HStack(spacing: Constants.textSpacing) {
      if !event.isRead { unreadIndicator() }
      Text(event.date, format: .relative(presentation: .named))
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func unreadIndicator() -> some View {
    Circle().fill(Color.accentColor)
      .frame(width: Constants.dotSize, height: Constants.dotSize)
      .accessibilityLabel(.activityUnread)
  }

  private var title: LocalizedStringResource {
    switch event.content {
    case .reply: .activityReplyFrom(event.owner?.nickname ?? "")
    case .indirectReplies: .activityIndirectReplies
    case let .friendRequest(from): .activityFriendRequestFrom(from.nickname)
    case let .friendRequestAccepted(from): .activityFriendRequestAccepted(from.nickname)
    }
  }

  private var openHint: LocalizedStringResource {
    switch event.content {
    case .reply: .activityOpenHint
    case .indirectReplies: .activityOpenThreadHint
    case .friendRequest, .friendRequestAccepted: .activityOpenProfileHint
    }
  }

  private var symbol: String {
    switch event.content {
    case .reply: Constants.replySymbol
    case .indirectReplies: Constants.threadSymbol
    case .friendRequest: Constants.requestSymbol
    case .friendRequestAccepted: Constants.acceptedSymbol
    }
  }

  private var symbolColor: Color {
    switch event.content {
    case .reply: Constants.replyColor
    case .indirectReplies: Constants.threadColor
    case .friendRequest: Constants.requestColor
    case .friendRequestAccepted: Constants.acceptedColor
    }
  }
}

private enum Constants {
  static let spacing: CGFloat = 12
  static let textSpacing: CGFloat = 6
  static let avatarSize: CGFloat = 44
  static let badgeSize: CGFloat = 24
  static let symbolSize: CGFloat = 11
  static let badgeOffset: CGFloat = 4
  static let verticalPadding: CGFloat = 6
  static let dotSize: CGFloat = 7
  static let previewLines = 2
  static let borderOpacity = 0.25
  static let badgeBackground = Color(uiColor: .secondarySystemGroupedBackground)
  static let replySymbol = "arrowshape.turn.up.left.fill"
  static let threadSymbol = "dot.radiowaves.left.and.right"
  static let requestSymbol = "person.badge.plus"
  static let acceptedSymbol = "person.crop.circle.badge.checkmark"
  static let replyColor = Color.blue
  static let threadColor = Color.indigo
  static let requestColor = Color.orange
  static let acceptedColor = Color.green
}
