struct ConfirmationCode {
  let int: Int

  init?(_ value: String) {
    let digits = Self.sanitize(value)
    guard digits.count == 8, let int = Int(digits), (10_000_000...99_999_999).contains(int) else {
      return nil
    }
    self.int = int
  }

  static func sanitize(_ value: String) -> String {
    String(value.filter { $0.isASCII && $0.isNumber }.prefix(8))
  }
}
