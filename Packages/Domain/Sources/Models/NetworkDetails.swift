public struct NetworkDetails: Sendable {
    public let friends: [UserDetails]

    public init(friends: [UserDetails]) {
        self.friends = friends
    }
}
