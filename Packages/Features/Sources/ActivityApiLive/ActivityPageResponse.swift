import ActivityService
import CommunityService
import Foundation

struct ActivityPageResponse: Decodable {
  let data: [EventResponse]
  let nextId: String?

  func events() throws -> [ActivityEvent] {
    try data.compactMap { try $0.map() }
  }

  struct EventResponse: Decodable {
    let type: String
    let id: Int64
    let instant: String
    let isRead: Bool
    let post: PostResponse?
  }

  struct PostResponse: Decodable {
    let id: Int64
    let accessHash: String
    let instant: String
    let text: String
    let owner: OwnerResponse
    let edited: Bool

    func value() throws -> CommunityPost {
      .published(.init(
        descriptor: .init(id: id, accessHash: accessHash), text: text,
        owner: owner.value, date: try parseDate(instant), edited: edited))
    }
  }

  struct OwnerResponse: Decodable {
    let id: Int64
    let accessHash: String
    let nickname: String
    let avatar: AvatarResponse?

    var value: CommunityPost.Owner {
      .init(id: id, accessHash: accessHash, nickname: nickname,
            avatar: avatar.map { .init(id: $0.id, accessHash: $0.accessHash) })
    }
  }

  struct AvatarResponse: Decodable {
    let id: Int64
    let accessHash: String
  }
}

private extension ActivityPageResponse.EventResponse {
  func map() throws -> ActivityEvent? {
    guard type == "new_reply" else { return nil }
    guard let post else { throw ActivityError.invalidResponse }
    return .init(id: id, date: try parseDate(instant), isRead: isRead, reply: try post.value())
  }
}

private func parseDate(_ value: String) throws -> Date {
  guard let date = (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    ?? (try? Date(value, strategy: .iso8601)) else { throw ActivityError.invalidResponse }
  return date
}
