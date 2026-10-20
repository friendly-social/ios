import ActivityApi
import Dependencies

extension ActivityApi: DependencyKey {
  public static var liveValue: Self {
    let live = ActivityApiLive()
    return .init(
      list: { try await live.list(cursor: $0, credentials: $1) },
      hasNewUnreads: { try await live.hasNewUnreads(credentials: $0) },
      acknowledgeUnreads: { try await live.acknowledgeUnreads(credentials: $0) },
      markRead: { try await live.markRead(id: $0, credentials: $1) })
  }
}
