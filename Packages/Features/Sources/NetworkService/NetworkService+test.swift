public import Dependencies

extension NetworkService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
