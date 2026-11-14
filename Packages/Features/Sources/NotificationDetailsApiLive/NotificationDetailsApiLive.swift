import Dependencies
import FilesApi
import Foundation
import Models
import Networking
import NotificationDetailsApi

struct NotificationDetailsApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client
  @Dependency(FilesApi.self) private var files

  func content(id: Int64, session: NotificationSession) async throws -> NotificationContent {
    let response = try await response(id: id, session: session)
    return NotificationContent(
      details: response.notification(using: files),
      target: response.target
    )
  }
}

private extension NotificationDetailsApiLive {
  private func response(
    id: Int64,
    session: NotificationSession
  ) async throws -> NotificationDetailsResponse {
    let response: HTTPResponse
    do {
      response = try await client.send(request(id: id, session: session))
    } catch {
      try Task.checkCancellation()
      throw NotificationDetailsError.unavailable
    }
    guard response.statusCode != 401 else { throw NotificationDetailsError.unauthorized }
    guard response.statusCode == 200 else { throw NotificationDetailsError.unavailable }
    do {
      return try client.decode(NotificationDetailsResponse.self, from: response)
    } catch {
      throw NotificationDetailsError.invalidResponse
    }
  }

  private func request(id: Int64, session: NotificationSession) -> HTTPClient.Request {
    HTTPClient.Request(
      path: "notifications/details/\(id)",
      headers: [
        "Cache-Control": "no-store",
        "X-Token": session.token.string,
        "X-User-Id": String(session.userID.int64),
      ],
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeout: Constants.requestTimeout
    )
  }
}

private enum Constants {
  static let requestTimeout: TimeInterval = 12
}
