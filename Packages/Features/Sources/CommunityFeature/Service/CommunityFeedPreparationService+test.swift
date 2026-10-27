import Dependencies

extension CommunityFeedPreparationService: TestDependencyKey {
  public static var testValue: Self {
    .init(prepareDocument: { _ in nil })
  }
}
