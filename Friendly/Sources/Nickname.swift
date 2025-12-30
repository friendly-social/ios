struct Nickname: Equatable, Hashable {
    let string: String

    init(_ string: String) throws(Error) {
        if string.count > Nickname.maxLength {
            throw .maxLength
        }
        self.string = string
    }

    static let maxLength: Int = 256

    enum Error : Swift.Error {
        case maxLength
    }
}

