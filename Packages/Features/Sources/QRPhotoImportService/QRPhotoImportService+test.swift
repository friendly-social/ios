public import Dependencies

extension QRPhotoImportService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
