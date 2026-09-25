import Dependencies

extension SecureStorageService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
