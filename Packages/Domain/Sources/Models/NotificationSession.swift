public struct NotificationSession: Equatable, Sendable {
  public let userID: UserId
  public let token: Token

  public init(userID: UserId, token: Token) {
    self.userID = userID
    self.token = token
  }
}
