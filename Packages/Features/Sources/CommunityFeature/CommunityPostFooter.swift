import CommunityService
import Foundation
import SwiftUI

struct CommunityPostFooter: View {
  let owners: [CommunityPost.Owner]
  let avatarURL: (CommunityPost.Owner.Avatar) -> URL
  let alignment: Alignment
  let showsReplySymbol: Bool
  let reply: () -> Void
  let openDetails: (() -> Void)?

  init(
    owners: [CommunityPost.Owner], avatarURL: @escaping (CommunityPost.Owner.Avatar) -> URL,
    alignment: Alignment = .trailing, showsReplySymbol: Bool = true,
    reply: @escaping () -> Void,
    openDetails: (() -> Void)? = nil
  ) {
    self.owners = owners
    self.avatarURL = avatarURL
    self.alignment = alignment
    self.showsReplySymbol = showsReplySymbol
    self.reply = reply
    self.openDetails = openDetails
  }

  var body: some View {
    contentView()
  }
}

private extension CommunityPostFooter {
  private var participants: [CommunityPost.Owner] {
    var seen: Set<Int64> = []
    return Array(
      owners.reversed().filter { seen.insert($0.id).inserted }.prefix(Constants.maxAvatars))
  }
  @ViewBuilder
  private func contentView() -> some View {
    Group {
      if let openDetails, !participants.isEmpty {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: Constants.spacing) {
            Button(action: openDetails) {
              avatars()
                .frame(minHeight: Constants.touchTarget)
                .contentShape(.rect)
            }
            .accessibilityLabel(.postReadAll)
            replyButton()
          }
          replyButton()
        }
      } else {
        Button(action: reply) {
          replyContentView()
            .frame(minHeight: Constants.touchTarget)
            .contentShape(.rect)
        }
        .accessibilityLabel(.postReplyHint)
      }
    }
    .buttonStyle(.plain)
    .foregroundStyle(Constants.foreground)
    .frame(maxWidth: .infinity, alignment: alignment)
  }

  private func replyButton() -> some View {
    Button(action: reply) {
      replyLabel()
        .frame(minHeight: Constants.touchTarget)
        .contentShape(.rect)
    }
    .accessibilityLabel(.postReplyHint)
  }

  private func avatars() -> some View {
    HStack(spacing: Constants.overlap) {
      ForEach(participants, id: \.id) { owner in
        CommunityAvatar(owner: owner, avatarURL: avatarURL)
          .frame(width: Constants.avatarSize, height: Constants.avatarSize)
          .overlay { Circle().strokeBorder(Constants.border, lineWidth: Constants.borderWidth) }
      }
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func replyLabel() -> some View {
    Group {
      if showsReplySymbol && participants.isEmpty {
        Label(.postReply, systemImage: Constants.reply)
      } else {
        Text(.postReply)
      }
    }
    .font(.subheadline.weight(.medium))
    .fixedSize(horizontal: true, vertical: false)
  }

  @ViewBuilder
  private func replyContentView() -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Constants.spacing) {
        if !participants.isEmpty { avatars() }
        replyLabel()
      }
      replyLabel()
    }
  }
}

private enum Constants {
  static let maxAvatars = 5
  static let spacing: CGFloat = 8
  static let overlap: CGFloat = -10
  static let avatarSize: CGFloat = 26
  static let borderWidth: CGFloat = 2
  static let touchTarget: CGFloat = 44
  static let foreground = Color.secondary
  static let border = Color(uiColor: .systemBackground)
  static let reply = "bubble"
}
