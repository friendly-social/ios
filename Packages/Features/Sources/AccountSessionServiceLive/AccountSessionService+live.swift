public import AccountSessionService
public import Dependencies

extension AccountSessionService {
  public static func live() -> Self {
    let live = AccountSessionServiceLive()
    return .init(clearAuthorization: { live.clearAuthorization() })
  }
}

extension AccountSessionService: DependencyKey {
  public static var liveValue: Self { .live() }
}
