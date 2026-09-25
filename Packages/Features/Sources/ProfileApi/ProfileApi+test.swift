import Dependencies

extension ProfileApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
