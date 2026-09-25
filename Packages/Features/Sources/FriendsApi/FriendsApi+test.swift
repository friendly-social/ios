import Dependencies

extension FriendsApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
