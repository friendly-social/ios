struct SocialLink {
    let string: String

    init(_ string: String) throws(Error) {
        if string.count > SocialLink.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    static let maxLength: Int = 2048

    enum Error: Swift.Error {
        case maxLength
    }
}
