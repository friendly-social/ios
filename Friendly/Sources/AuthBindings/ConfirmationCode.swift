struct ConfirmationCode {
    let int: Int

    init?(_ value: String) {
        let digits = Self.sanitize(value)
        guard digits.count == 8, let int = Int(digits) else {
            return nil
        }
        self.int = int
    }

    static func sanitize(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(8))
    }
}
