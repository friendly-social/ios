public struct Authorization: Sendable {
    public let token: Token
    public let id: UserId
    public let accessHash: UserAccessHash

    public init(token: Token, id: UserId, accessHash: UserAccessHash) {
        self.token = token
        self.id = id
        self.accessHash = accessHash
    }
}
