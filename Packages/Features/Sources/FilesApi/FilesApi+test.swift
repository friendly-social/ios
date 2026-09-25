import Dependencies

extension FilesApi: TestDependencyKey {
  public static var testValue: Self { .init() }
}
