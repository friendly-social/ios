struct UserDetails {
    let id: UserId
    let accessHash: UserAccessHash
    let nickname: Nickname
    let description: UserDescription
    let interests: [Interest]
    let avatar: FileDescriptor?
    let socialLink: SocialLink?

    func serializable() -> UserDetailsSerializable {
        return UserDetailsSerializable(
            id: id.int64,
            accessHash: accessHash.string,
            nickname: nickname.string,
            description: description.string,
            interests: interests.map(\.string),
            avatar: avatar?.serializable(),
            socialLink: socialLink?.string,
        )
    }
}
