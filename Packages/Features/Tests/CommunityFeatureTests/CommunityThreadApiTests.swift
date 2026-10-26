import AccountStorageService
import CommunityApi
import CommunityApiLive
@testable import CommunityFeature
import CommunityService
import CommunityServiceLive
import Dependencies
import Foundation
import Models
import Networking
import Testing

@MainActor
struct CommunityThreadApiTests {
  @Test func consecutiveRepliesReachHTTPWithCorrectParentsAndLoadAsThread() async throws {
    let server = ThreadHTTPFixture()
    let service = try makeService(server: server)
    let model = makeDetailModel(post: post(1), service: service)
    defer { model.stop() }
    await model.load()
    try await publish("**First**", in: model)
    try await publish("Second", in: model)
    #expect(await server.publications == [
      .init(parentID: 1, accessHash: "hash-1", text: "**First**"),
      .init(parentID: 2, accessHash: "hash-2", text: "Second")
    ])
    #expect(model.post.id == 3 && model.upstream.map(\.id) == [1, 2])
    model.select(post(1))
    await model.load()
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3]])
    #expect(model.nextID == "next")
    await model.loadMore()
    #expect(model.replyGroups.map { $0.rows.map(\.id) } == [[2, 3], [4, 5], [6]])
    #expect(model.nextID == nil)
    #expect(await server.paths.contains("/community/1/hash-1/replies2/next"))
  }

  @Test func sameAuthorSiblingRepliesStaySeparate() async throws {
    let server = ThreadHTTPFixture()
    let service = try makeService(server: server)
    let page = try await service.replies(post(1).descriptor, "siblings")
    guard case let .single(first) = page.data[0], case let .single(second) = page.data[1] else {
      Issue.record("Sibling replies were grouped locally")
      return
    }
    #expect(first.owner == second.owner)
    #expect(first.id == 2 && second.id == 3)
  }

  @Test(arguments: ["empty", "unknown"])
  func invalidReplyPayloadIsRejected(cursor: String) async throws {
    let service = try makeService(server: ThreadHTTPFixture())
    await #expect(throws: DecodingError.self) {
      try await service.replies(post(1).descriptor, cursor)
    }
  }
}

private extension CommunityThreadApiTests {
  private func publish(_ text: String, in model: CommunityPostDetailViewModel) async throws {
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.editor.loadSource(text)
    composer.textChanged()
    await composer.publish()
    #expect(composer.published != nil)
  }

  private func makeService(server: ThreadHTTPFixture) throws -> CommunityService {
    let token = String(repeating: "t", count: Token.length)
    let authorization = try Authorization(
      token: Token(token), id: UserId(7),
      accessHash: UserAccessHash(String(repeating: "a", count: UserAccessHash.length)))
    var storage = AccountStorageService()
    storage.loadAuthorization = { authorization }
    let transport = HTTPTransport(
      data: { try await server.respond(to: $0) },
      upload: { _, _ in throw CommunityError.unavailable })
    let client = HTTPClient(baseURL: URL(string: "https://example.com")!, transport: transport)
    let api = withDependencies { $0[HTTPClient.self] = client } operation: { CommunityApi.live() }
    return withDependencies {
      $0[AccountStorageService.self] = storage
      $0[CommunityApi.self] = api
    } operation: { CommunityService.live() }
  }
}

private actor ThreadHTTPFixture {
  struct Publication: Equatable, Sendable {
    let parentID: Int64
    let accessHash: String
    let text: String
  }

  private(set) var publications: [Publication] = []
  private(set) var paths: [String] = []

  func respond(to request: URLRequest) throws -> HTTPResponse {
    let url = try #require(request.url)
    #expect(url.host == "example.com")
    #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
    #expect(request.value(forHTTPHeaderField: "X-Token") == String(repeating: "t", count: Token.length))
    paths.append(url.path)
    if url.path == "/community" { return try publish(request) }
    if url.path.hasSuffix("/read") {
      #expect(request.httpMethod == "POST")
      return HTTPResponse(data: Data(), statusCode: 200)
    }
    #expect(request.httpMethod == "GET")
    if url.path.contains("/replies2/") { return try page(cursor: url.lastPathComponent) }
    let parts = url.pathComponents
    #expect(parts.count == 5 && parts[1] == "community" && parts[2] == "2")
    let id = try #require(Int64(parts[3]))
    #expect(parts[4] == "hash-\(id)")
    return try details(id)
  }

  private func publish(_ request: URLRequest) throws -> HTTPResponse {
    #expect(request.httpMethod == "POST")
    let bytes = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let parent = try #require(body["replyTo"] as? [String: Any])
    publications.append(try Publication(
      parentID: #require(parent["id"] as? Int64),
      accessHash: #require(parent["accessHash"] as? String), text: #require(body["text"] as? String)))
    let id = publications.count + 1
    return try response(["id": id, "accessHash": "hash-\(id)"])
  }

  private func details(_ id: Int64) throws -> HTTPResponse {
    let replies: [[String: Any]] = id == 1 && publications.count == 2
      ? [["type": "thread", "thread": [payload(2), payload(3)]]] : []
    var page: [String: Any] = ["data": replies, "nextId": NSNull()]
    if !replies.isEmpty { page["nextId"] = "next" }
    return try response(["post": payload(id), "upstream": (1..<id).map(payload), "replies": page])
  }

  private func page(cursor: String) throws -> HTTPResponse {
    let data: [[String: Any]]
    switch cursor {
    case "next": data = [
      ["type": "thread", "thread": [payload(4), payload(5)]],
      ["type": "single", "post": payload(6)]
    ]
    case "siblings": data = [
      ["type": "single", "post": payload(2)], ["type": "single", "post": payload(3)]
    ]
    case "empty": data = [["type": "thread", "thread": []]]
    case "unknown": data = [["type": "unexpected"]]
    default: throw CommunityError.unavailable
    }
    return try response(["data": data, "nextId": NSNull()])
  }

  private func payload(_ id: Int64) -> [String: Any] {
    ["id": id, "accessHash": "hash-\(id)", "type": "plain", "text": "Post \(id)",
     "instant": "2026-10-25T10:00:00Z", "edited": false, "replyPreviews": [],
     "newUnreadId": NSNull(), "owner": ["id": 7, "accessHash": "owner", "nickname": "Author"]]
  }

  private func response(_ object: [String: Any]) throws -> HTTPResponse {
    HTTPResponse(data: try JSONSerialization.data(withJSONObject: object), statusCode: 200)
  }
}

private func post(_ id: Int64) -> CommunityPost {
  .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "hash-\(id)"), text: "Post \(id)"))
}
