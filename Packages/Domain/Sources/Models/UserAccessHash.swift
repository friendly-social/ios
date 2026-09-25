public struct UserAccessHash: Sendable, Equatable, Hashable {
    public let string: String

    public init(_ string: String) throws(Error) {
        if string.count != UserAccessHash.length {
            throw .length
        }
        self.string = string
    }

    public static let length: Int = 256

    public enum Error: Swift.Error {
        case length
    }
}
