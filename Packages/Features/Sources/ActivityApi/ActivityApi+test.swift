import Dependencies

extension ActivityApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
