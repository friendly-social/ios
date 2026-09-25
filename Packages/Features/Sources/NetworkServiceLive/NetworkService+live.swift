public import NetworkService
public import Dependencies

extension NetworkService {
  static func live() -> Self {
    let live = NetworkServiceLive()
    return .init(
      loadFriends: { try await live.loadFriends() },
      generateInvitationURL: { try await live.generateInvitationURL() },
      generateQRCode: { live.generateQRCode(for: $0) }
    )
  }
}

extension NetworkService: DependencyKey {
  public static var liveValue: Self { .live() }
}
