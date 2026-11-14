import Dependencies
import Foundation
import Models
import NotificationDetailsApi
import NotificationEnrichmentService
import NotificationEnrichmentServiceLive
import NotificationSessionStorage
import Synchronization
import Testing
import UserNotifications

struct NotificationEnrichmentServiceTests {
  @Test(arguments: [false, true])
  func rendersFriendshipWithoutASecondLine(isMutual: Bool) async throws {
    let session = try session()
    let result = await withDependencies {
      $0[NotificationSessionStorage.self].load = { session }
      $0[NotificationDetailsApi.self].content = { _, _ in
        NotificationContent(
          details: .friendRequest(nickname: "Kai", isMutual: isMutual),
          target: nil
        )
      }
    } operation: {
      await NotificationEnrichmentService.liveValue.content(request: request())
    }
    let content = try #require(result)
    #expect(content.title.contains("Kai"))
    #expect(content.body.isEmpty)
  }

  @Test func rendersReplyAndKeepsNavigationContextWithoutTheSessionToken() async throws {
    let session = try session()
    let result = await withDependencies {
      $0[NotificationSessionStorage.self].load = { session }
      $0[NotificationDetailsApi.self].content = { _, _ in
        NotificationContent(
          details: .reply(nickname: "Kai", text: "Thanks!"),
          target: .reply(id: 12, accessHash: "reply-hash")
        )
      }
    } operation: {
      await NotificationEnrichmentService.liveValue.content(request: request())
    }
    let content = try #require(result)
    #expect(content.title.contains("Kai"))
    #expect(content.body == "Thanks!")
    let encoded = try #require(content.userInfo["friendly.context"] as? String)
    #expect(!encoded.contains(session.token.string))
    let context = try JSONDecoder().decode(NotificationContext.self, from: Data(encoded.utf8))
    let target = context.target(notificationID: 42, accountID: 7)
    #expect(target == .reply(id: 12, accessHash: "reply-hash"))
  }

  @Test func unknownEventPreservesTheOriginalFallback() async throws {
    let session = try session()
    let result = await withDependencies {
      $0[NotificationSessionStorage.self].load = { session }
      $0[NotificationDetailsApi.self].content = { _, _ in
        throw NotificationDetailsError.invalidResponse
      }
    } operation: {
      await NotificationEnrichmentService.liveValue.content(request: request())
    }
    #expect(result == nil)
  }

  @Test func changedSessionDiscardsLoadedDetails() async throws {
    let current = Mutex<NotificationSession?>(try session())
    let result = await withDependencies {
      $0[NotificationSessionStorage.self].load = { current.withLock { $0 } }
      $0[NotificationDetailsApi.self].content = { _, _ in
        current.withLock { $0 = nil }
        return NotificationContent(details: .reply(nickname: "Kai", text: "Private"), target: nil)
      }
    } operation: {
      await NotificationEnrichmentService.liveValue.content(request: request())
    }
    #expect(result == nil)
  }
}

private extension NotificationEnrichmentServiceTests {
  private func session() throws -> NotificationSession {
    NotificationSession(
      userID: UserId(7),
      token: try Token(String(repeating: "t", count: Token.length))
    )
  }

  private func request() -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.body = "New notification"
    content.userInfo = ["id": "42"]
    return UNNotificationRequest(identifier: "42", content: content, trigger: nil)
  }
}
