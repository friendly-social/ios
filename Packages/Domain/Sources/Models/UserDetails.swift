public struct UserDetails: Sendable {
    public let id: UserId
    public let accessHash: UserAccessHash
    public let nickname: Nickname
    public let description: UserDescription
    public let interests: [Interest]
    public let avatar: FileDescriptor?
    public let socialLink: SocialLink?
    public let email: String?

    public init(id: UserId, accessHash: UserAccessHash, nickname: Nickname, description: UserDescription, interests: [Interest], avatar: FileDescriptor?, socialLink: SocialLink?, email: String?) {
        self.id = id
        self.accessHash = accessHash
        self.nickname = nickname
        self.description = description
        self.interests = interests
        self.avatar = avatar
        self.socialLink = socialLink
        self.email = email
    }
}
