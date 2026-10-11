import ActivityApi
import Dependencies

extension ActivityApi: DependencyKey {
  public static var liveValue: Self {
    let live = ActivityApiLive()
    return .init(
      list: { try await live.list(cursor: $0, credentials: $1) },
      markRead: { try await live.markRead(id: $0, credentials: $1) })
  }
}
