import Dependencies

extension AuthApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
