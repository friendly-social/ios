import Dependencies

extension CommunityApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
