struct Token: Equatable, Hashable {
    let string: String

    init(_ string: String) throws(Error) {
        if string.count != Token.length {
            throw .length
        }
        self.string = string
    }

    static let length: Int = 256

    enum Error: Swift.Error {
        case length
    }
}

