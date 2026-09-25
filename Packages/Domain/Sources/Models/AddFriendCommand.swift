public struct AddFriendCommand: Sendable {
    public let id: UserId
    public let token: FriendToken

    public init(id: UserId, token: FriendToken) {
        self.id = id
        self.token = token
    }
}
