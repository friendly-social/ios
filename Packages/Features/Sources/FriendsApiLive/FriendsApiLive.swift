import Dependencies
import Foundation
import FriendsApi
import Models
import Networking

struct FriendsApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func networkDetails(_ authorization: Authorization) async throws -> NetworkDetails {
    let response: NetworkDetailsResponse = try await send(
      path: "network/details", authorization: authorization)
    return NetworkDetails(friends: try response.friends.map { try $0.domain() })
  }

  func generate(_ authorization: Authorization) async throws -> FriendToken {
    let response: GenerateResponse = try await send(
      path: "friends/generate", method: .post, authorization: authorization)
    return try FriendToken(response.token)
  }

  func add(_ authorization: Authorization, token: FriendToken, id: UserId) async throws {
    let body = AddRequest(token: token.string, userId: id.int64)
    let response: AddResponse = try await send(
      path: "friends/add", method: .post, body: body, authorization: authorization)
    if response.type == "FriendTokenExpired" { throw FriendsApi.Error.expiredToken }
  }

  func decline(_ authorization: Authorization, id: UserId, accessHash: UserAccessHash) async throws {
    let body = FriendRequest(userId: id.int64, userAccessHash: accessHash.string)
    let _: EmptyResponse = try await send(
      path: "friends/decline", method: .post, body: body, authorization: authorization)
  }

  func request(_ authorization: Authorization, id: UserId, accessHash: UserAccessHash) async throws {
    let body = FriendRequest(userId: id.int64, userAccessHash: accessHash.string)
    let _: EmptyResponse = try await send(
      path: "friends/request", method: .post, body: body, authorization: authorization)
  }
}

private extension FriendsApiLive {
  private func send<Response: Decodable>(
    path: String,
    method: HTTPClient.Method = .get,
    authorization: Authorization
  ) async throws -> Response {
    try await send(path: path, method: method, body: Optional<String>.none, authorization: authorization)
  }

  private func send<Body: Encodable, Response: Decodable>(
    path: String,
    method: HTTPClient.Method,
    body: Body?,
    authorization: Authorization
  ) async throws -> Response {
    var request = HTTPClient.Request(
      path: path,
      method: method,
      headers: [
        "Cache-Control": "no-cache",
        "Content-Type": "application/json",
        "X-Token": authorization.token.string,
        "X-User-Id": String(authorization.id.int64),
      ],
      cachePolicy: .reloadIgnoringLocalCacheData)
    do {
      if let body { try request.encode(body) }
      let response = try await client.send(request)
      if response.statusCode == 401 { throw FriendsApi.Error.unauthorized }
      guard response.statusCode == 200 else {
        throw FriendsApi.Error.serverError(statusCode: response.statusCode)
      }
      return try client.decode(response)
    } catch let error as FriendsApi.Error {
      throw error
    } catch {
      throw FriendsApi.Error.ioError(error)
    }
  }
}

private struct NetworkDetailsResponse: Decodable {
  let friends: [UserDetailsResponse]
}

private struct UserDetailsResponse: Decodable {
  let id: Int64
  let accessHash: String
  let nickname: String
  let description: String
  let interests: [String]
  let avatar: FileDescriptorResponse?
  let socialLink: String?
  let email: String?

  func domain() throws -> UserDetails {
    try UserDetails(
      id: UserId(id),
      accessHash: UserAccessHash(accessHash),
      nickname: Nickname(nickname),
      description: UserDescription(description),
      interests: interests.map(Interest.init),
      avatar: avatar?.domain(),
      socialLink: socialLink.map(SocialLink.init),
      email: email)
  }
}

private struct FileDescriptorResponse: Decodable {
  let id: Int64
  let accessHash: String

  func domain() throws -> FileDescriptor {
    try FileDescriptor(id: FileId(id), accessHash: FileAccessHash(accessHash))
  }
}

private struct GenerateResponse: Decodable { let token: String }
private struct AddRequest: Encodable { let token: String; let userId: Int64 }
private struct AddResponse: Decodable { let type: String }
private struct FriendRequest: Encodable { let userId: Int64; let userAccessHash: String }
private struct EmptyResponse: Decodable {}
