import ActivityService
import Dependencies

extension ActivityService: DependencyKey {
  public static var liveValue: Self { live() }

  public static func live() -> Self {
    let live = ActivityServiceLive()
    return .init(
      list: { try await live.list($0, session: $1) },
      openReply: { try await live.openReply($0, session: $1) },
      markRead: { try await live.markRead($0, session: $1) })
  }
}
