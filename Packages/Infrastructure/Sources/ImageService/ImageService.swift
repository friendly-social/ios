import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct ImageService: Sendable {
  public var prepare: @Sendable () -> Void
  public var load: @Sendable (URL) async throws -> Data
  public var cached: @Sendable (URL) -> Data?
  public var remember: @Sendable (Data, URL) -> Void

  public enum Error: Swift.Error, Sendable {
    case invalidURL
    case unavailable
  }
}

extension ImageService: TestDependencyKey {
  public static var testValue: Self {
    .init(prepare: {}, load: { _ in throw Error.unavailable }, cached: { _ in nil }, remember: { _, _ in })
  }
}
