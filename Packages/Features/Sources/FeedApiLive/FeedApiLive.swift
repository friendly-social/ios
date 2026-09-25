import Dependencies
import FeedApi
import Foundation
import Models
import Networking

struct FeedApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func queue(_ authorization: Authorization) async throws -> FeedQueue {
    let request = HTTPClient.Request(
      path: "feed/queue",
      headers: [
        "Cache-Control": "no-cache",
        "Content-Type": "application/json",
        "X-Token": authorization.token.string,
        "X-User-Id": String(authorization.id.int64),
      ],
      cachePolicy: .reloadIgnoringLocalCacheData)
    do {
      let response = try await client.send(request)
      if response.statusCode == 401 { throw FeedApi.Error.unauthorized }
      guard response.statusCode == 200 else {
        throw FeedApi.Error.serverError(statusCode: response.statusCode)
      }
      let body: FeedQueueResponse = try client.decode(response)
      return FeedQueue(entries: try body.entries.map { try $0.domain() })
    } catch let error as FeedApi.Error {
      throw error
    } catch {
      throw FeedApi.Error.ioError(error)
    }
  }
}

private struct FeedQueueResponse: Decodable {
  let entries: [Entry]

  struct Entry: Decodable {
    let isRequest: Bool
    let isExtendedNetwork: Bool
    let commonFriends: [UserDetailsResponse]
    let details: UserDetailsResponse

    func domain() throws -> FeedQueue.Entry {
      try FeedQueue.Entry(
        isRequest: isRequest,
        isExtendedNetwork: isExtendedNetwork,
        commonFriends: commonFriends.map { try $0.domain() },
        details: details.domain())
    }
  }
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
