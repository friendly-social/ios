import CommunityProfileService
import CommunityService
import DependenciesMacros
import Foundation

@DependencyClient
public struct ActivityService: Sendable {
  public var list: @Sendable (String?, CommunitySession) async throws -> ActivityPage
  public var openReply: @Sendable (PostDescriptor, CommunitySession) async throws -> ActivityDiscussion
  public var hasNewUnreads: @Sendable (CommunitySession) async throws -> Bool
  public var acknowledgeUnreads: @Sendable (CommunitySession) async throws -> Void
  public var markRead: @Sendable (Int64, CommunitySession) async throws -> Void
}

public struct ActivityEvent: Sendable, Equatable, Identifiable {
  public let id: Int64
  public let date: Date
  public var isRead: Bool
  public let reply: CommunityPost
  public let preview: String

  public init(id: Int64, date: Date, isRead: Bool, reply: CommunityPost, preview: String = "") {
    self.id = id
    self.date = date
    self.isRead = isRead
    self.reply = reply
    self.preview = preview
  }
}

public struct ActivityPage: Sendable {
  public let events: [ActivityEvent]
  public let nextID: String?

  public init(events: [ActivityEvent], nextID: String?) {
    self.events = events
    self.nextID = nextID
  }
}

public struct ActivityDiscussion: Sendable, Identifiable, Hashable {
  public let details: CommunityPostDetails
  public let replyID: Int64
  public var id: Int64 { replyID }

  public init(details: CommunityPostDetails, replyID: Int64) {
    self.details = details
    self.replyID = replyID
  }

  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.replyID == rhs.replyID }

  public func hash(into hasher: inout Hasher) { hasher.combine(replyID) }
}

public enum ActivityError: Error, Equatable {
  case unavailable
  case invalidResponse
}
