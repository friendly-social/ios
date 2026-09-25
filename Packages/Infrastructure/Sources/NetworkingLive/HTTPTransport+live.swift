import Dependencies
import Networking

extension HTTPTransport {
  public static func live() -> Self {
    let live = HTTPTransportLive()
    return .init(data: live.data, upload: live.upload)
  }
}

extension HTTPTransport: DependencyKey {
  public static var liveValue: Self { .live() }
}
