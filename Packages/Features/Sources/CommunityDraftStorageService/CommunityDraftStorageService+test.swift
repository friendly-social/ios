public import Dependencies

extension CommunityDraftStorageService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
