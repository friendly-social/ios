import Dependencies

extension CommunityDraftService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
