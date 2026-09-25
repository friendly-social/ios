import DependenciesMacros
import Models

@DependencyClient
public struct FeedApi: Sendable {
  public var queue: @Sendable (Authorization) async throws -> FeedQueue

  public enum Error: Swift.Error {
    case ioError(Swift.Error)
    case serverError(statusCode: Int)
    case unauthorized
  }
}
