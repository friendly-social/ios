import Dependencies
import FriendsApi

extension FriendsApi {
  public static func live() -> Self {
    let live = FriendsApiLive()
    return .init(
      networkDetails: { try await live.networkDetails($0) },
      friendsGenerate: { try await live.generate($0) },
      friendsAdd: { try await live.add($0, token: $1, id: $2) },
      friendsDecline: { try await live.decline($0, id: $1, accessHash: $2) },
      friendsRequest: { try await live.request($0, id: $1, accessHash: $2) })
  }
}

extension FriendsApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
