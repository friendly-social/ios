public import Dependencies
public import InvitationService

extension InvitationService: DependencyKey {
  public static var liveValue: Self {
    let live = InvitationServiceLive()
    return .init(
      generateInvitation: { try await live.generateInvitation(force: $0) },
      copyLink: { await live.copyLink($0) }
    )
  }
}
