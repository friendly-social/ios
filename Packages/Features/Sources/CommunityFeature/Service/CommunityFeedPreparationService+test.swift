import Dependencies

extension CommunityFeedPreparationService: TestDependencyKey {
  public static var testValue: Self {
    .init(prepareExcerpt: { _ in nil })
  }
}
