public import Dependencies

extension QRSessionService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
