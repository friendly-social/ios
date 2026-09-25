import AuthApi
import Dependencies

extension AuthApi {
  public static func live() -> Self {
    let client = AuthApiLive()
    return .init(
      authGenerate: { try await client.generate($0, $1, $2, $3, $4) },
      authEmail: { try await client.requestEmailCode($0) },
      authLogin: { try await client.login($0, $1) },
      emailLink: { try await client.linkEmail($0, $1) },
      emailConfirm: { try await client.confirmEmail($0, $1) },
      emailUnlink: { try await client.unlinkEmail($0) }
    )
  }
}

extension AuthApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
