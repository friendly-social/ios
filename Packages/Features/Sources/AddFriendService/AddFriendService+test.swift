import Dependencies

extension AddFriendService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
