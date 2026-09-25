import Dependencies

extension CommunityService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
