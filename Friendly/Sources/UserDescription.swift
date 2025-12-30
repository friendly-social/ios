struct UserDescription: Equatable, Hashable {
    let string: String

    init(_ string: String) throws(Error) {
        if string.count > UserDescription.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    static let maxLength: Int = 1024

    enum Error : Swift.Error {
        case maxLength
    }
}

