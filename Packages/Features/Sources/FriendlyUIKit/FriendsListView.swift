import SwiftUI

public struct FriendsListView<Friend: Identifiable>: View {
  private let friends: [Friend]
  private let nickname: (Friend) -> String
  private let avatarURL: (Friend) -> URL?
  private let onSelect: (Friend) -> Void

  public init(
    friends: [Friend], nickname: @escaping (Friend) -> String,
    avatarURL: @escaping (Friend) -> URL?, onSelect: @escaping (Friend) -> Void
  ) {
    self.friends = friends
    self.nickname = nickname
    self.avatarURL = avatarURL
    self.onSelect = onSelect
  }

  public var body: some View {
    LazyVStack(spacing: Constants.listSpacing) {
      ForEach(friends) { friend in
        friendRow(friend)
      }
    }
    .padding()
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: Constants.listCornerRadius))
    .padding()
  }
}

private extension FriendsListView {
  private func friendRow(_ friend: Friend) -> some View {
    Button { onSelect(friend) } label: {
      HStack {
        AvatarView(url: avatarURL(friend), size: Constants.avatarSize)
        Text(nickname(friend)).font(.body)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

private enum Constants {
  static let avatarSize: CGFloat = 50
  static let listSpacing: CGFloat = 12
  static let listCornerRadius: CGFloat = 20
}
