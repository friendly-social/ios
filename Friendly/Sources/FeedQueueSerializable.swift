struct FeedQueueSerializable: Codable {
    let entries: [Entry]

    func typed() throws -> FeedQueue {
        let entries = try self.entries.map { entry in
            let commonFriends = try entry
                .commonFriends
                .map { friend in try friend.typed() }
            return FeedQueue.Entry(
                isRequest: entry.isRequest,
                isExtendedNetwork: entry.isExtendedNetwork,
                commonFriends: commonFriends,
                details: try entry.details.typed(),
            )
        }
        return FeedQueue(entries: entries)
    }

    struct Entry: Codable {
        let isRequest: Bool
        let isExtendedNetwork: Bool
        let commonFriends: [UserDetailsSerializable]
        let details: UserDetailsSerializable
    }
}

