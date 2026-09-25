public struct FeedQueue: Sendable {
    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public struct Entry: Sendable {
        public let isRequest: Bool
        public let isExtendedNetwork: Bool
        public let commonFriends: [UserDetails]
        public let details: UserDetails

        public init(isRequest: Bool, isExtendedNetwork: Bool, commonFriends: [UserDetails], details: UserDetails) {
            self.isRequest = isRequest
            self.isExtendedNetwork = isExtendedNetwork
            self.commonFriends = commonFriends
            self.details = details
        }
    }
}
