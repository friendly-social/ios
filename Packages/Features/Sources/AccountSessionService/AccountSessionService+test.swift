import Dependencies

extension AccountSessionService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
