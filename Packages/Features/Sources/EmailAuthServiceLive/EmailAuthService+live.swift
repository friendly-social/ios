public import Dependencies
public import EmailAuthService

private extension EmailAuthService {
  private static func live() -> Self {
    let live = EmailAuthServiceLive()
    return .init(
      requestBindingCode: { email in try await live.requestBindingCode(email: email) },
      confirmBinding: { email, code in try await live.confirmBinding(email: email, code: code) },
      requestLoginCode: { email in try await live.requestLoginCode(email: email) },
      login: { email, code in try await live.login(email: email, code: code) }
    )
  }
}

extension EmailAuthService: DependencyKey {
  public static var liveValue: Self { .live() }
}
