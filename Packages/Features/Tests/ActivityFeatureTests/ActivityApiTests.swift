import ActivityApi
@testable import ActivityApiLive
import ActivityService
@testable import ActivityServiceLive
import CommunityService
import CustomDump
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
    #expect(page.events.first?.post?.descriptor == .init(id: 30, accessHash: "reply-hash"))
    #expect(page.events.first?.post?.owner?.nickname == "Аня")
    #expect(page.events.first?.post?.owner?.avatar?.id == 90)
    #expect(page.events.first?.isRead == false)
  }

  @Test(arguments: [false, true])
  func decodesNewUnreadIndicator(hasNew: Bool) async throws {
    let api = makeAPI { request in
      expectNoDifference(request.url?.path, "/activity/unreads/new")
      expectNoDifference(request.httpMethod, "GET")
      expectNoDifference(request.value(forHTTPHeaderField: "X-Token"), "token")
      let body = hasNew ? #"{"type":"some","activityId":42}"# : #"{"type":"none"}"#
      return .init(data: Data(body.utf8), statusCode: 200)
    }
    let result = try await api.hasNewUnreads(credentials)
    expectNoDifference(result, hasNew)
  }

  @Test func acknowledgementAcceptsEmptyResponseAndSendsSessionHeaders() async throws {
    let api = makeAPI { request in
      expectNoDifference(request.url?.path, "/activity/unreads/acknowledge")
      expectNoDifference(request.httpMethod, "POST")
      expectNoDifference(request.value(forHTTPHeaderField: "X-User-Id"), "7")
      expectNoDifference(request.value(forHTTPHeaderField: "X-Token"), "token")
      #expect(request.httpBody == nil)
      return .init(data: Data(), statusCode: 200)
    }
    try await api.acknowledgeUnreads(credentials)
  }

  @Test func unreadIndicatorRejectsUnknownResponseInsteadOfClearingBadge() async {
    let api = makeAPI { _ in
      .init(data: Data(#"{"type":"future"}"#.utf8), statusCode: 200)
    }
    await #expect(throws: (any Error).self) { try await api.hasNewUnreads(credentials) }
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

  @Test func decodesIndirectRepliesWithTheirDiscussionDestination() async throws {
    let response = try #require(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
    let data = try #require(response["data"] as? [[String: Any]])
    var item = try #require(data.first)
    item["type"] = "indirect_replies"
    var common = try #require(item["post"] as? [String: Any])
    common["id"] = 20
    item["commonDenominator"] = common
    let body = try JSONSerialization.data(withJSONObject: ["data": [item]])
    let api = makeAPI { _ in .init(data: body, statusCode: 200) }
    let page = try await api.list(nil, credentials)
    let event = try #require(page.events.first)
    guard case let .indirectReplies(post, commonDenominator) = event.content else {
      Issue.record("Expected indirect replies")
      return
    }
    expectNoDifference(post.id, 30)
    expectNoDifference(commonDenominator.id, 20)
  }

  @Test(arguments: [false, true])
  func decodesFriendRequestsWithoutRequiringAPost(isMutual: Bool) async throws {
    let body = requestPayload.replacingOccurrences(of: "false", with: String(isMutual))
    let api = makeAPI { _ in .init(data: Data(body.utf8), statusCode: 200) }
    let page = try await api.list(nil, credentials)
    let event = try #require(page.events.first)
    let from = CommunityPost.Owner(id: 8, accessHash: "user-hash", nickname: "Аня")
    let expected: ActivityEvent.Content = isMutual
      ? .friendRequestAccepted(from: from)
      : .friendRequest(from: from)
    expectNoDifference(event.content, expected)
    #expect(event.post == nil)
  }

  @Test func unknownEventWithoutReplyIsSkippedWithoutLosingCursor() async throws {
    let api = makeAPI { _ in .init(data: Data(unknownPayload.utf8), statusCode: 200) }
    let page = try await api.list(nil, credentials)
    #expect(page.events.isEmpty)
    expectNoDifference(page.nextID, "next")
  }

  @Test(arguments: ["new_reply", "indirect_replies", "new_request"])
  func knownEventMissingRequiredContentFails(type: String) async {
    let body = unknownPayload.replacingOccurrences(of: "future", with: type)
    let api = makeAPI { _ in .init(data: Data(body.utf8), statusCode: 200) }
    await #expect(throws: ActivityError.invalidResponse) { try await api.list(nil, credentials) }
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
{"data":[{"type":"new_reply","id":42,"instant":"2026-10-11T10:00:00.123456789Z","isRead":false,
"post":{"id":30,"accessHash":"reply-hash","instant":"2026-10-11T10:00:00Z","text":"**Привет**","edited":false,
"owner":{"id":8,"accessHash":"user-hash","nickname":"Аня","avatar":{"id":90,"accessHash":"avatar-hash"}}}}],"nextId":"next"}
"""#

private let unknownPayload = #"""
{"data":[{"type":"future","id":1,"instant":"2026-10-11T10:00:00Z","isRead":false}],"nextId":"next"}
"""#

private let requestPayload = #"""
{"data":[{"type":"new_request","id":43,"instant":"2026-10-11T10:00:00Z","isRead":true,
"from":{"id":8,"accessHash":"user-hash","nickname":"Аня"},"isMutual":false}]}
"""#
