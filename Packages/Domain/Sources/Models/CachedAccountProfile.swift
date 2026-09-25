public struct CachedAccountProfile: Codable, Sendable {
  public let id: Int64
  public let accessHash: String
  public let nickname: String
  public let avatarID: Int64?
  public let avatarAccessHash: String?

  public init(
    id: Int64,
    accessHash: String,
    nickname: String,
    avatarID: Int64?,
    avatarAccessHash: String?
  ) {
    self.id = id
    self.accessHash = accessHash
    self.nickname = nickname
    self.avatarID = avatarID
    self.avatarAccessHash = avatarAccessHash
  }
}
