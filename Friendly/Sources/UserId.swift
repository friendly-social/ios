struct UserId: Equatable, Hashable {
    let int64: Int64

    init(_ int64: Int64) {
        self.int64 = int64
    }
}
