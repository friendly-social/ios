import Dependencies
import ProfileApi

extension ProfileApi {
  public static func live() -> Self {
    let client = ProfileApiLive()
    return .init(
      usersDetails: { try await client.details($0, $1, $2) },
      usersEdit: { try await client.edit($0, $1, $2, $3, $4, $5) }
    )
  }
}

extension ProfileApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
