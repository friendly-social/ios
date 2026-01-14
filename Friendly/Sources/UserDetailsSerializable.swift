struct UserDetailsSerializable: Codable {
    let id: Int64
    let accessHash: String
    let nickname: String
    let description: String
    let interests: [String]
    let avatar: FileDescriptorSerializable?
    let socialLink: String?

    func typed() throws -> UserDetails {
        let socialLink: SocialLink? =
            if let socialLink = socialLink {
                try SocialLink(socialLink)
            } else {
                nil
            }
        return UserDetails(
            id: UserId(id),
            accessHash: try UserAccessHash(accessHash),
            nickname: try Nickname(nickname),
            description: try UserDescription(description),
            interests: try interests.map { interest in
                try Interest(interest)
            },
            avatar: try avatar?.typed(),
            socialLink: socialLink,
        )
    }
}
