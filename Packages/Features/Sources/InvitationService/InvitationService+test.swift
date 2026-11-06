public import Dependencies

extension InvitationService: TestDependencyKey {
  public static var testValue: Self { .init() }
}
