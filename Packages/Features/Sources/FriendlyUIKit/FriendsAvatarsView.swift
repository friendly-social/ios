import SwiftUI

public struct FriendsAvatarsView: View {
  private let preview: FriendsPreview

  public init(preview: FriendsPreview) {
    self.preview = preview
  }

  public var body: some View {
    HStack(spacing: -Constants.avatarOverlap) {
      ForEach(preview.avatars) { avatar in
        AvatarView(url: avatar.url, size: Constants.avatarSize)
          .padding(Constants.avatarPadding)
          .background(.ultraThinMaterial, in: .circle)
      }
      if preview.remainingCount > 0 { remainingView() }
    }
    .padding(Constants.stackPadding)
    .background { Color.clear.glassEffect(.regular.tint(.gray.opacity(Constants.glassTint))) }
    .clipShape(.capsule)
    .accessibilityHidden(true)
  }
}

private extension FriendsAvatarsView {
  private func remainingView() -> some View {
    Text("+\(preview.remainingCount)").font(.caption.weight(.semibold)).lineLimit(1)
      .minimumScaleFactor(Constants.minimumTextScale).foregroundStyle(.primary)
      .frame(width: Constants.avatarSize, height: Constants.avatarSize)
      .padding(Constants.avatarPadding)
      .background(.ultraThinMaterial, in: .circle)
  }
}

private enum Constants {
  static let avatarSize: CGFloat = 40
  static let avatarOverlap: CGFloat = 21
  static let avatarPadding: CGFloat = 3
  static let stackPadding: CGFloat = 2
  static let glassTint: Double = 0.2
  static let minimumTextScale: CGFloat = 0.6
}
