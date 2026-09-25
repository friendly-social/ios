import Dependencies

extension FeedApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
