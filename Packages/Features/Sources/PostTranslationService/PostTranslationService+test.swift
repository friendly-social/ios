import Dependencies

extension PostTranslationService: TestDependencyKey {
  public static var testValue: Self {
    var service = Self()
    service.load = { _ in nil }
    return service
  }
  public static var previewValue: Self { testValue }
}
