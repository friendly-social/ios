public struct FileId: Sendable, Equatable, Hashable {
    public let int64: Int64

    public init(_ int64: Int64) {
        self.int64 = int64
    }
}
