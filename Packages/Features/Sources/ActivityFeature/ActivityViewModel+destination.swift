import ActivityService
import CommunityProfileService
import Models

extension ActivityViewModel {
  public enum Destination: Identifiable {
    case discussion(Discussion)
    case profile(Profile)

    public var id: Int64 {
      switch self {
      case let .discussion(destination): destination.event.id
      case let .profile(destination): destination.event.id
      }
    }
  }
}

extension ActivityViewModel.Destination {
  public struct Discussion: Hashable {
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

  public struct Profile: Identifiable {
    public var id: Int64 { event.id }
    public let event: ActivityEvent
    public let session: CommunitySession
    public let userID: UserId
    public let accessHash: UserAccessHash
  }
}

extension ActivityViewModel.Destination {
  public var discussion: Discussion? {
    guard case let .discussion(destination) = self else { return nil }
    return destination
  }

  public var profile: Profile? {
    guard case let .profile(destination) = self else { return nil }
    return destination
  }
}
