import ActivityService
import Dependencies

extension ActivityService: DependencyKey {
  public static var liveValue: Self { live() }

  public static func live() -> Self {
    let live = ActivityServiceLive()
    return .init(
      list: { try await live.list($0, session: $1) },
      openThread: { try await live.openThread($0, session: $1) },
      openReply: { try await live.openReply($0, session: $1) },
      hasNewUnreads: { try await live.hasNewUnreads(session: $0) },
      acknowledgeUnreads: { try await live.acknowledgeUnreads(session: $0) },
      markRead: { try await live.markRead($0, session: $1) })
  }
}
