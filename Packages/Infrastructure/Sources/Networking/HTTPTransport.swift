import DependenciesMacros
import Foundation

@DependencyClient
public struct HTTPTransport: Sendable {
  public var data: @Sendable (URLRequest) async throws -> HTTPResponse
  public var upload: @Sendable (URLRequest, Data) async throws -> HTTPResponse
}

public struct HTTPResponse: Sendable {
  public let data: Data
  public let statusCode: Int

  public init(data: Data, statusCode: Int) {
    self.data = data
    self.statusCode = statusCode
  }
}
