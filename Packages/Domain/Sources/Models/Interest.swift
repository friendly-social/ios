public struct Interest: Sendable, Equatable, Hashable {
    public let string: String

    public init(_ string: String) throws(Error) {
        if string.count > Interest.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    public static let maxLength: Int = 64

    public enum Error: Swift.Error {
        case maxLength
    }
}
