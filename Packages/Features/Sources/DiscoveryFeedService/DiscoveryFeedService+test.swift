public import Dependencies

extension DiscoveryFeedService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
