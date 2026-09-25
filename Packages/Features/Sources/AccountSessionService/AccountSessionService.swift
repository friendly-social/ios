import DependenciesMacros

@DependencyClient
public struct AccountSessionService: Sendable {
  public var clearAuthorization: @Sendable () -> Void = {}
}
