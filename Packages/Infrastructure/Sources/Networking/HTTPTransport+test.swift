import Dependencies

extension HTTPTransport: TestDependencyKey {
  public static var testValue: Self { .init() }
}
