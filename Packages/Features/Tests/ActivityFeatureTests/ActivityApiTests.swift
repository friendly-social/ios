import ActivityApi
@testable import ActivityApiLive
import ActivityService
@testable import ActivityServiceLive
import CommunityService
import Dependencies
import Foundation
import Networking
import Testing

struct ActivityApiTests {
  @Test func decodesBackendReplyAndSendsSessionHeaders() async throws {
    let api = makeAPI { request in
      #expect(request.url?.path == "/activity/list/cursor")
      #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
      #expect(request.value(forHTTPHeaderField: "X-Token") == "token")
      return .init(data: Data(payload.utf8), statusCode: 200)
    }
    let page = try await api.list("cursor", credentials)
    #expect(page.nextID == "next")
    #expect(page.events.count == 1)
    #expect(page.events.first?.reply.descriptor == .init(id: 30, accessHash: "reply-hash"))
    #expect(page.events.first?.reply.owner?.nickname == "Аня")
    #expect(page.events.first?.reply.owner?.avatar?.id == 90)
    #expect(page.events.first?.isRead == false)
  }

  @Test func readAcceptsEmptySuccessfulResponse() async throws {
    let api = makeAPI { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == "/activity/read/42")
      return .init(data: Data(), statusCode: 200)
    }
    try await api.markRead(42, credentials)
  }

  @Test func unauthorizedResponseIsMappedToContractError() async {
    let api = makeAPI { _ in .init(data: Data(), statusCode: 401) }
    await #expect(throws: CommunityError.unauthorized) { try await api.list(nil, credentials) }
  }

  @Test func unknownEventWithoutReplyIsSkippedWithoutLosingCursor() async throws {
    let api = makeAPI { _ in
      .init(data: Data(#"{"data":[{"type":"future","id":1,"instant":"2026-10-11T10:00:00Z","isRead":false}],"nextId":"next"}"#.utf8), statusCode: 200)
    }
    let page = try await api.list(nil, credentials)
    #expect(page.events.isEmpty)
    #expect(page.nextID == "next")
  }

  @Test func textPreviewOmitsMarkdownSyntaxAndDoesNotRenderImages() {
    #expect(ActivityPreview.text("**Hello** ![mountains](https://example.com/a.png)") == "Hello mountains")
    #expect(ActivityPreview.text(String(repeating: "a", count: 500)).count == 240)
  }
}

private extension ActivityApiTests {
  private var credentials: ActivityCredentials { .init(accountID: 7, token: "token") }

  private func makeAPI(
    _ response: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
  ) -> ActivityApi {
    let transport = HTTPTransport(data: response, upload: { _, _ in throw ActivityError.unavailable })
    let client = HTTPClient(baseURL: URL(string: "https://example.com")!, transport: transport)
    return withDependencies { $0[HTTPClient.self] = client } operation: { ActivityApi.liveValue }
  }
}

private let payload = #"""
{"data":[{"type":"reply","id":42,"instant":"2026-10-11T10:00:00.123456789Z","isRead":false,
"post":{"id":30,"accessHash":"reply-hash","instant":"2026-10-11T10:00:00Z","text":"**Привет**","edited":false,
"owner":{"id":8,"accessHash":"user-hash","nickname":"Аня","avatar":{"id":90,"accessHash":"avatar-hash"}}}}],"nextId":"next"}
"""#
