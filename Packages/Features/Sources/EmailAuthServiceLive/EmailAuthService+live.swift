public import EmailAuthService
public import Dependencies

extension EmailAuthService {
  static func live() -> Self {
    let live = EmailAuthServiceLive()
    return .init(
      requestBindingCode: { try await live.requestBindingCode(email: $0) },
      confirmBinding: { try await live.confirmBinding(code: $0) },
      requestLoginCode: { try await live.requestLoginCode(email: $0) },
      login: { try await live.login(email: $0, code: $1) }
    )
  }
}

extension EmailAuthService: DependencyKey {
  public static var liveValue: Self { .live() }
}
