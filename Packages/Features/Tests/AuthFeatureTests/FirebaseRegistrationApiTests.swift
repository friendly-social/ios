import AuthApi
import AuthApiLive
import Dependencies
import Foundation
import Models
import Networking
import Testing

struct FirebaseRegistrationApiTests {
  @Test func registersUsingTheSharedFirebaseTokenContract() async throws {
    let authorization = try Authorization(
      token: Token(String(repeating: "t", count: Token.length)),
      id: UserId(7),
      accessHash: UserAccessHash(String(repeating: "h", count: UserAccessHash.length))
    )
    let transport = HTTPTransport(
      data: { request in
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/auth/firebase")
        #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
        #expect(request.value(forHTTPHeaderField: "X-Token") == authorization.token.string)
        let body = try #require(request.httpBody)
        let payload = try JSONDecoder().decode([String: String].self, from: body)
        #expect(payload == ["firebaseToken": "test-fcm-token"])
        return HTTPResponse(data: Data(), statusCode: 200)
      },
      upload: { _, _ in throw URLError(.unsupportedURL) }
    )
    let baseURL = try #require(URL(string: "https://example.com"))
    let client = HTTPClient(baseURL: baseURL, transport: transport)
    let api = withDependencies { $0[HTTPClient.self] = client } operation: { AuthApi.live() }
    try await api.registerFirebaseToken(
      authorization: authorization,
      firebaseToken: "test-fcm-token"
    )
  }
}
