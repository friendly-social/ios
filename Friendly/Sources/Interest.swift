struct Interest: Equatable, Hashable {
    let string: String

    init(_ string: String) throws(Error) {
        if string.count > Interest.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    static let maxLength: Int = 64

    enum Error: Swift.Error {
        case maxLength
    }
}

