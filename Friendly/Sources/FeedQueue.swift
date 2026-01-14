struct FeedQueue {
    let entries: [Entry]

    func serializable() -> FeedQueueSerializable {
        let entries = self.entries.map { entry in
            let commonFriends = entry
                .commonFriends
                .map { friend in friend.serializable() }
            return FeedQueueSerializable.Entry(
                isRequest: entry.isRequest,
                isExtendedNetwork: entry.isExtendedNetwork,
                commonFriends: commonFriends,
                details: entry.details.serializable(),
            )
        }
        return FeedQueueSerializable(entries: entries)
    }

    struct Entry {
        let isRequest: Bool
        let isExtendedNetwork: Bool
        let commonFriends: [UserDetails]
        let details: UserDetails
    }
}

