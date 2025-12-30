struct FileDescriptor {
    let id: FileId
    let accessHash: FileAccessHash

    func serializable() -> FileDescriptorSerializable {
        let id = id.int64
        let accessHash = accessHash.string
        return FileDescriptorSerializable(id: id, accessHash: accessHash)
    }
}
