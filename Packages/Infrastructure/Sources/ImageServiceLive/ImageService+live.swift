import Dependencies
import ImageService

extension ImageService: DependencyKey {
  public static var liveValue: Self {
    let live = ImageServiceLive()
    return .init(prepare: { live.prepare() }, load: { try await live.load($0) },
      cached: { live.cached($0) }, remember: { live.remember($0, for: $1) })
  }
}
