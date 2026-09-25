import CommunityService
import Foundation
import SwiftUI

struct CommunityComposePrompt: View {
  let owner: CommunityPost.Owner?
  let draftState: CommunityViewModel.DraftState
  let avatarURL: (CommunityPost.Owner.Avatar) -> URL
  let compose: () -> Void

  var body: some View {
    contentView()
  }
}

private extension CommunityComposePrompt {

  @ViewBuilder
  private func contentView() -> some View {
    Button(action: compose) {
      promptLabelView()
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityHint(
      .feedComposeHint)
  }

  @ViewBuilder
  private func promptTextView() -> some View {
    VStack(alignment: .leading, spacing: Constants.textSpacing) {
      (owner.map { Text($0.nickname) } ?? Text(.postYou))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Constants.primary)
      Text(draftState == .available ? .feedContinueDraft : .feedPrompt)
        .font(.body)
        .foregroundStyle(draftState == .available ? Color.accentColor : Constants.secondary)
        .lineLimit(1)
        .opacity(draftState == .unknown ? 0 : 1)
        .accessibilityHidden(draftState == .unknown)
    }
  }

  @ViewBuilder
  private func promptLabelView() -> some View {
    HStack(alignment: .center, spacing: Constants.columnSpacing) {
      CommunityAvatar(owner: owner, avatarURL: avatarURL)
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
      promptTextView()
      Spacer(minLength: Constants.zero)
    }
  }
}

private enum Constants {
  static let zero: CGFloat = 0
  static let columnSpacing: CGFloat = 10
  static let textSpacing: CGFloat = 4
  static let avatarSize: CGFloat = 40
  static let horizontalPadding: CGFloat = 16
  static let verticalPadding: CGFloat = 16
  static let primary = Color.primary
  static let secondary = Color.secondary
}
