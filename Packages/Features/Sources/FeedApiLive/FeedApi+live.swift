import Dependencies
import FeedApi

extension FeedApi {
  public static func live() -> Self {
    let live = FeedApiLive()
    return .init(queue: { try await live.queue($0) })
  }
}

extension FeedApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
