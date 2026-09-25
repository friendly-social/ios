public import Dependencies

extension CameraPermissionService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
