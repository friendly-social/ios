public import Dependencies

extension ProfileService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
