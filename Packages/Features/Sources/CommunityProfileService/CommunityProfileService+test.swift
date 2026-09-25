import Dependencies

extension CommunityProfileService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
