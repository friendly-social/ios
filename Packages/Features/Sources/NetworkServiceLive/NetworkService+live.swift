public import Dependencies
public import NetworkService

extension NetworkService {
  static func live() -> Self {
    let live = NetworkServiceLive()
    return .init(loadFriends: live.loadFriends)
  }
}

extension NetworkService: DependencyKey {
  public static var liveValue: Self { .live() }
}
