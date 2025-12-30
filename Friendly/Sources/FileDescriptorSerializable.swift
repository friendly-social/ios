struct FileDescriptorSerializable : Codable {
    let id: Int64
    let accessHash: String

    func typed() throws(FileAccessHash.Error) -> FileDescriptor {
        let id = FileId(id)
        let accessHash = try FileAccessHash(accessHash)
        return FileDescriptor(id: id, accessHash: accessHash)
    }
}
