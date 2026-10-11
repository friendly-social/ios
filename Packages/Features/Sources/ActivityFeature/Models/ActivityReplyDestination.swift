import ActivityService
import CommunityProfileService

public struct ActivityReplyDestination: Hashable {
  public let event: ActivityEvent
  public let session: CommunitySession

  init(event: ActivityEvent, session: CommunitySession) {
    self.event = event
    self.session = session
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.event.id == rhs.event.id && lhs.session == rhs.session
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(event.id)
    hasher.combine(session.sessionID)
  }
}
