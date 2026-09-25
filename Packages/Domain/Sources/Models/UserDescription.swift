public struct UserDescription: Sendable, Equatable, Hashable {
    public let string: String

    public init(_ string: String) throws(Error) {
        if string.count > UserDescription.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    public static let maxLength: Int = 1024

    public enum Error: Swift.Error {
        case maxLength
    }
}
