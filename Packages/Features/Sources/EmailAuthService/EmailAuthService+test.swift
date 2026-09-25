public import Dependencies

extension EmailAuthService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
