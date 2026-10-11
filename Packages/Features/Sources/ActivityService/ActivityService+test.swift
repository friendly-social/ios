import Dependencies

extension ActivityService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
