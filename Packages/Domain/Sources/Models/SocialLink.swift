public struct SocialLink: Sendable {
    public let string: String

    public init(_ string: String) throws(Error) {
        if string.count > SocialLink.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    public static let maxLength: Int = 2048

    public enum Error: Swift.Error {
        case maxLength
    }
}
