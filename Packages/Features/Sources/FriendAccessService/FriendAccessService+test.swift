public import Dependencies

extension FriendAccessService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
