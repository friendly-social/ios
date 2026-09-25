public struct Nickname: Sendable, Equatable, Hashable {
    public let string: String

    public init(_ string: String) throws(Error) {
        if string.count > Nickname.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    public static let maxLength: Int = 256

    public enum Error: Swift.Error {
        case maxLength
    }
}
