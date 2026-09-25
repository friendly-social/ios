import Dependencies

extension AccountStorageService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
