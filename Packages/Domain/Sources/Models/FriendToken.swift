public struct FriendToken: Sendable, Equatable, Hashable {
  public let string: String

  public init(_ string: String) {
    self.string = string
  }
}
