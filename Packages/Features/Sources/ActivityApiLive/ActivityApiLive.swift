import ActivityApi
import ActivityService
import CommunityService
import Dependencies
import Networking

struct ActivityApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func list(cursor: String?, credentials: ActivityCredentials) async throws -> ActivityPage {
    let path = cursor.map { "activity/list/\($0)" } ?? "activity/list"
    let response = try await perform(path: path, credentials: credentials)
    let decoded: ActivityPageResponse = try client.decode(response)
    return .init(events: try decoded.events(), nextID: decoded.nextId)
  }

  func hasNewUnreads(credentials: ActivityCredentials) async throws -> Bool {
    let response = try await perform(path: "activity/unreads/new", credentials: credentials)
    let decoded: UnreadsResponse = try client.decode(response)
    return decoded.type == .some
  }

  func acknowledgeUnreads(credentials: ActivityCredentials) async throws {
    _ = try await perform(path: "activity/unreads/acknowledge", method: .post, credentials: credentials)
  }

  func markRead(id: Int64, credentials: ActivityCredentials) async throws {
    _ = try await perform(path: "activity/read/\(id)", method: .post, credentials: credentials)
  }
}

private struct UnreadsResponse: Decodable {
  enum Kind: String, Decodable { case none, some }
  let type: Kind
}

private extension ActivityApiLive {
  private func perform(
    path: String, method: HTTPClient.Method = .get, credentials: ActivityCredentials
  ) async throws -> HTTPResponse {
    let request = HTTPClient.Request(
      path: path, method: method,
      headers: ["X-Token": credentials.token, "X-User-Id": String(credentials.accountID)],
      cachePolicy: .reloadIgnoringLocalCacheData)
    let response = try await client.send(request)
    switch response.statusCode {
    case 200..<300: return response
    case 401: throw CommunityError.unauthorized
    case 404: throw ActivityError.unavailable
    default: throw CommunityError.rejected(response.statusCode)
    }
  }
}
