public struct AddFriendCommand: Sendable {
  public let token: FriendToken

  public init(token: FriendToken) {
    self.token = token
  }
}
