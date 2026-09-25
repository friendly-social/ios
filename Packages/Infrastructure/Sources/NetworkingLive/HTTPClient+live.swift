import Dependencies
import Foundation
import Networking
import URLMacro

extension HTTPClient {
  public static func live() -> Self {
    @Dependency(HTTPTransport.self) var transport
    return .init(baseURL: #URL("https://api.getfriend.ly"), transport: transport)
  }
}

extension HTTPClient: DependencyKey {
  public static var liveValue: Self { .live() }
}
