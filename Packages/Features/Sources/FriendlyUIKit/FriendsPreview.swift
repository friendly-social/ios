import Foundation
import Models

public struct FriendsPreview {
  public struct Avatar: Identifiable {
    public let id: UserId
    public let url: URL?
  }

  public let avatars: [Avatar]
  public let names: String
  public let remainingCount: Int

  public init(friends: [FriendSummary]) {
    let visible = Array(friends.prefix(Constants.limit))
    avatars = visible.map { Avatar(id: $0.id, url: $0.avatarURL) }
    names = visible.map(\.nickname.string).joined(separator: ", ")
    remainingCount = friends.count - visible.count
  }
}

private enum Constants {
  static let limit = 5
}
