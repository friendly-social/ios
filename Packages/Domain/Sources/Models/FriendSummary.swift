import Foundation

public struct FriendSummary: Identifiable, Sendable {
  public let id: UserId
  public let accessHash: UserAccessHash
  public let nickname: Nickname
  public let avatarURL: URL?

  public init(id: UserId, accessHash: UserAccessHash, nickname: Nickname, avatarURL: URL?) {
    self.id = id
    self.accessHash = accessHash
    self.nickname = nickname
    self.avatarURL = avatarURL
  }
}
