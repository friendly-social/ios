import Foundation
import Networking

struct HTTPTransportLive: Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func data(_ request: URLRequest) async throws -> HTTPResponse {
    let (data, response) = try await session.data(for: request)
    return HTTPResponse(data: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
  }

  func upload(_ request: URLRequest, from data: Data) async throws -> HTTPResponse {
    let (data, response) = try await session.upload(for: request, from: data)
    return HTTPResponse(data: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
  }
}
