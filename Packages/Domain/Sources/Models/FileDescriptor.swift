public struct FileDescriptor: Sendable {
    public let id: FileId
    public let accessHash: FileAccessHash

    public init(id: FileId, accessHash: FileAccessHash) {
        self.id = id
        self.accessHash = accessHash
    }
}
