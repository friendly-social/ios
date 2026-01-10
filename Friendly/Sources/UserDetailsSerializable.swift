struct UserDetailsSerializable: Codable {
    let id: Int64
    let accessHash: String
    let nickname: String
    let description: String
    let interests: [String]
    let avatar: FileDescriptorSerializable?

    func typed() throws -> UserDetails {
        return UserDetails(
            id: UserId(id),
            accessHash: try UserAccessHash(accessHash),
            nickname: try Nickname(nickname),
            description: try UserDescription(description),
            interests: try interests.map { interest in
                try Interest(interest)
            },
            avatar: try avatar?.typed(),
        )
    }
}
