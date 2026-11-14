import Dependencies
import FilesApi
import Foundation
import Models
import Networking
import NotificationDetailsApi
import NotificationDetailsApiLive
import Synchronization
import Testing

struct NotificationDetailsApiTests {
  @Test func renderingAndNavigationUseOneResponse() async throws {
    let calls = Mutex(0)
    let hash = String(repeating: "h", count: UserAccessHash.length)
    let body = """
    {"type":"new_request","from":{"id":9,"accessHash":"\(hash)","nickname":"Kai"},"isMutual":false}
    """
    let api = makeAPI { _ in
      calls.withLock { $0 += 1 }
      return HTTPResponse(data: Data(body.utf8), statusCode: 200)
    }
    let content = try await api.content(id: 42, session: makeSession())
    #expect(content.details == .friendRequest(nickname: "Kai", isMutual: false))
    #expect(content.target == .profile(id: UserId(9), accessHash: try UserAccessHash(hash)))
    #expect(calls.withLock { $0 } == 1)
  }

  @Test(arguments: [false, true])
  func friendNotificationsOpenTheSenderProfile(isMutual: Bool) async throws {
    let hash = String(repeating: "h", count: UserAccessHash.length)
    let body = """
    {"type":"new_request","from":{"id":9,"accessHash":"\(hash)","nickname":"Kai"},
      "isMutual":\(isMutual)}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(body.utf8), statusCode: 200) }
    let target = try await api.content(id: 42, session: makeSession()).target
    #expect(target == .profile(id: UserId(9), accessHash: try UserAccessHash(hash)))
  }

  @Test func replyNotificationIncludesTheExactReplyDescriptor() async throws {
    let body = """
    {"type":"new_reply","post":{"type":"plain","id":12,"accessHash":"reply-hash",
      "owner":{"nickname":"Kai"},"text":"Thanks!"}}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(body.utf8), statusCode: 200) }
    let target = try await api.content(id: 42, session: makeSession()).target
    #expect(target == .reply(id: 12, accessHash: "reply-hash"))
  }

  @Test func missingTargetDoesNotInventAProfileOrPost() async throws {
    let body = #"{"type":"new_request","from":{"nickname":"Kai"},"isMutual":false}"#
    let api = makeAPI { _ in HTTPResponse(data: Data(body.utf8), statusCode: 200) }
    let content = try await api.content(id: 42, session: makeSession())
    #expect(content.target == nil)
    #expect(content.details == .friendRequest(nickname: "Kai", isMutual: false))
  }

  @Test(arguments: [false, true])
  func decodesFriendRequest(isMutual: Bool) async throws {
    let session = try makeSession()
    let api = makeAPI { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.path == "/notifications/details/42")
      #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
      #expect(request.value(forHTTPHeaderField: "X-Token") == session.token.string)
      let body = """
      {"type":"new_request","from":{"nickname":"Аня"},"isMutual":\(isMutual)}
      """
      return HTTPResponse(data: Data(body.utf8), statusCode: 200)
    }
    let details = try await api.content(id: 42, session: session).details
    #expect(details == .friendRequest(nickname: "Аня", isMutual: isMutual))
  }

  @Test func decodesReplyAndRejectsDeletedPost() async throws {
    let session = try makeSession()
    let reply = """
    {"type":"new_reply","post":{"type":"plain","owner":{"nickname":"Kai"},"text":"Thanks!"}}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(reply.utf8), statusCode: 200) }
    let details = try await api.content(id: 42, session: session).details
    #expect(details == .reply(nickname: "Kai", text: "Thanks!"))
    let deleted = """
    {"type":"new_reply","post":{"type":"deleted",
      "owner":{"nickname":"Kai"},"text":"Deleted reply"}}
    """
    let deletedAPI = makeAPI { _ in HTTPResponse(data: Data(deleted.utf8), statusCode: 200) }
    await #expect(throws: NotificationDetailsError.invalidResponse) {
      try await deletedAPI.content(id: 42, session: session).details
    }
  }

  @Test func unauthorizedResponseCannotProvideNotificationText() async throws {
    let session = try makeSession()
    let api = makeAPI { _ in HTTPResponse(data: Data(), statusCode: 401) }
    await #expect(throws: NotificationDetailsError.unauthorized) {
      try await api.content(id: 42, session: session).details
    }
  }

  @Test func decodesReplySenderAvatar() async throws {
    let hash = String(repeating: "a", count: FileAccessHash.length)
    let reply = """
    {"type":"new_reply","post":{"type":"plain","owner":{
      "id":9,"nickname":"Kai","avatar":{"id":4,"accessHash":"\(hash)"}
    },"text":"Thanks!"}}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(reply.utf8), statusCode: 200) }
    let details = try await api.content(id: 42, session: makeSession()).details
    let image = NotificationSenderImage(
      senderID: 9,
      url: URL(string: "https://example.com/avatar/4")!
    )
    #expect(details == .reply(nickname: "Kai", text: "Thanks!", senderImage: image))
  }

  @Test(arguments: [false, true])
  func decodesFriendRequestSenderAvatar(isMutual: Bool) async throws {
    let hash = String(repeating: "a", count: FileAccessHash.length)
    let request = """
    {"type":"new_request","from":{
      "id":9,"nickname":"Kai","avatar":{"id":4,"accessHash":"\(hash)"}
    },"isMutual":\(isMutual)}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(request.utf8), statusCode: 200) }
    let details = try await api.content(id: 42, session: makeSession()).details
    let image = NotificationSenderImage(
      senderID: 9,
      url: URL(string: "https://example.com/avatar/4")!
    )
    #expect(details == .friendRequest(nickname: "Kai", isMutual: isMutual, senderImage: image))
  }

  @Test func invalidAvatarPreservesReplyText() async throws {
    let reply = """
    {"type":"new_reply","post":{"type":"plain","owner":{
      "id":9,"nickname":"Kai","avatar":{"id":4,"accessHash":"invalid"}
    },"text":"Thanks!"}}
    """
    let api = makeAPI { _ in HTTPResponse(data: Data(reply.utf8), statusCode: 200) }
    let details = try await api.content(id: 42, session: makeSession()).details
    #expect(details == .reply(nickname: "Kai", text: "Thanks!"))
  }
}

private extension NotificationDetailsApiTests {
  private func makeSession() throws -> NotificationSession {
    let token = try Token(String(repeating: "t", count: Token.length))
    return NotificationSession(userID: UserId(7), token: token)
  }

  private func makeAPI(
    _ response: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
  ) -> NotificationDetailsApi {
    let transport = HTTPTransport(
      data: response,
      upload: { _, _ in throw URLError(.unsupportedURL) }
    )
    let client = HTTPClient(baseURL: URL(string: "https://example.com")!, transport: transport)
    return withDependencies {
      $0[HTTPClient.self] = client
      $0[FilesApi.self].downloadURL = { URL(string: "https://example.com/avatar/\($0.id)")! }
    } operation: { NotificationDetailsApi.liveValue }
  }
}
