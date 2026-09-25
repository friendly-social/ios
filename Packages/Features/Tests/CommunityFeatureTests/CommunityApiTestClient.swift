@testable import CommunityApiLive
import Dependencies
import Foundation
import Networking
import Testing

func makeHTTPResponse(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
  let url = try #require(request.url)
  return try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
}

func makeCommunityApi(
  data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
) -> CommunityApiLive {
  let transport = HTTPTransport(
    data: { request in
      let (bytes, response) = try await data(request)
      return HTTPResponse(data: bytes, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
    },
    upload: { _, _ in throw URLError(.unsupportedURL) }
  )
  return withDependencies {
    $0[HTTPClient.self] = HTTPClient(
      baseURL: URL(string: "https://example.com") ?? URL(fileURLWithPath: "/"),
      transport: transport
    )
  } operation: {
    CommunityApiLive()
  }
}
