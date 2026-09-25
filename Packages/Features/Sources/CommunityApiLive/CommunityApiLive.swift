import CommunityApi
import CommunityService
import Dependencies
import Foundation
import Networking
import OSLog

public struct CommunityApiLive: Sendable {
  private static let logger = Logger(subsystem: "ly.getfriend.community", category: "HTTP")
  @Dependency(HTTPClient.self) private var client

  public func publish(_ text: String, replyTo: PostDescriptor? = nil, credentials: CommunityCredentials) async throws -> PostDescriptor {
    struct Body: Encodable { let text: String; let replyTo: PostDescriptor? }
    var request = request(path: "community", method: .post, credentials: credentials)
    try request.encode(Body(text: text, replyTo: replyTo))
    do {
      let response = try await perform(request)
      return try client.decode(response)
    } catch let error as CommunityError {
      throw error
    } catch {
      // The server might already have committed the post, including on cancellation.
      throw CommunityError.outcomeUnknown
    }
  }

  public func edit(id: Int64, text: String, credentials: CommunityCredentials) async throws {
    struct Field: Encodable { let value: String }
    struct Body: Encodable { let text: Field }
    var request = request(path: "community/\(id)/edit", method: .post, credentials: credentials)
    try request.encode(Body(text: Field(value: text)))
    try await mutate(request)
  }

  public func delete(id: Int64, credentials: CommunityCredentials) async throws {
    let request = request(path: "community/\(id)/delete", method: .post, credentials: credentials)
    try await mutate(request)
  }

  public func list(cursor: String?, credentials: CommunityCredentials) async throws -> CommunityPage {
    let path = cursor.map { "community/list/\($0)" } ?? "community/list"
    let request = request(path: path, credentials: credentials)
    Self.logger.debug("Community list: request started")
    let response = try await perform(request)
    do {
      let decoded: CommunityPageResponse = try client.decode(response)
      let page = decoded.page
      Self.logger.debug("Community list: decoded \(page.data.count) posts")
      return page
    } catch {
      switch error {
      case DecodingError.keyNotFound(let key, let context):
        Self.logger.error("Community list: missing key \(key.stringValue, privacy: .public), path \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public)")
      case DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context), DecodingError.dataCorrupted(let context):
        Self.logger.error("Community list: decoding failure at \(context.codingPath.map(\.stringValue).joined(separator: "."), privacy: .public)")
      default:
        Self.logger.error("Community list: unexpected decoding error")
      }
      throw error
    }
  }

  public func details(_ descriptor: PostDescriptor, credentials: CommunityCredentials) async throws -> CommunityPostDetails {
    let path = "community/2/\(descriptor.id)/\(descriptor.accessHash)"
    let response = try await perform(request(path: path, credentials: credentials))
    let decoded: CommunityPostDetailsResponse = try client.decode(response)
    return decoded.details
  }

  public func replies(
    to descriptor: PostDescriptor, cursor: String, credentials: CommunityCredentials
  ) async throws -> CommunityReplyPage {
    let request = request(
      path: "community/\(descriptor.id)/\(descriptor.accessHash)/replies2/\(cursor)", credentials: credentials)
    let response = try await perform(request)
    let decoded: CommunityReplyPageResponse = try client.decode(response)
    return decoded.page
  }
}

private extension CommunityApiLive {
  private func mutate(_ request: HTTPClient.Request) async throws {
    do {
      _ = try await perform(request)
    } catch let error as CommunityError {
      throw error
    } catch {
      throw CommunityError.outcomeUnknown
    }
  }

  private func request(
    path: String,
    method: HTTPClient.Method = .get,
    credentials: CommunityCredentials
  ) -> HTTPClient.Request {
    HTTPClient.Request(
      path: path,
      method: method,
      headers: [
        "Content-Type": "application/json",
        "X-Token": credentials.token,
        "X-User-Id": String(credentials.accountID)
      ],
      cachePolicy: .reloadIgnoringLocalCacheData
    )
  }

  private func perform(_ request: HTTPClient.Request) async throws -> HTTPResponse {
    let response: HTTPResponse
    do {
      response = try await client.send(request)
    } catch {
      Self.logger.error("Community transport failure: code \((error as NSError).code)")
      throw error
    }
    let bytes = response.data
    Self.logger.debug("Community HTTP status \(response.statusCode), bytes \(bytes.count)")
    switch response.statusCode {
    case 200..<300: return response
    case 401: throw CommunityError.unauthorized
    case 400..<500: throw CommunityError.rejected(response.statusCode)
    default: throw CommunityError.outcomeUnknown
    }
  }
}
