import CommunityService
import Foundation

struct CommunityPostResponse: Decodable {
  let post: CommunityPost

  private enum CodingKeys: String, CodingKey {
    case id, accessHash, type, text, owner, edited, instant, replyPreviews
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let descriptor = PostDescriptor(
      id: try values.decode(Int64.self, forKey: .id),
      accessHash: try values.decode(String.self, forKey: .accessHash)
    )
    let instant = try values.decode(String.self, forKey: .instant)
    guard let date = (try? Date(instant, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
      ?? (try? Date(instant, strategy: .iso8601)) else {
      throw DecodingError.dataCorruptedError(forKey: .instant, in: values, debugDescription: "Invalid post timestamp")
    }
    let type = try values.decodeIfPresent(String.self, forKey: .type) ?? "plain"
    let replyPreviews = try values.decodeIfPresent([OwnerResponse].self, forKey: .replyPreviews)?.map(\.owner) ?? []
    switch type {
    case "plain":
      post = .published(.init(
        descriptor: descriptor,
        text: try values.decode(String.self, forKey: .text),
        owner: try values.decode(OwnerResponse.self, forKey: .owner).owner,
        date: date,
        edited: try values.decode(Bool.self, forKey: .edited),
        replyPreviews: replyPreviews
      ))
    case "deleted":
      post = .deleted(.init(descriptor: descriptor, date: date, replyPreviews: replyPreviews))
    default:
      throw DecodingError.dataCorruptedError(forKey: .type, in: values, debugDescription: "Unknown post type")
    }
  }

  private struct OwnerResponse: Decodable {
    let id: Int64
    let accessHash: String
    let nickname: String
    let avatar: AvatarResponse?

    var owner: CommunityPost.Owner {
      .init(id: id, accessHash: accessHash, nickname: nickname, avatar: avatar.map {
        .init(id: $0.id, accessHash: $0.accessHash)
      })
    }
  }

  private struct AvatarResponse: Decodable {
    let id: Int64
    let accessHash: String
  }
}

struct CommunityPageResponse: Decodable {
  let data: [CommunityPostResponse]
  let nextId: String?

  var page: CommunityPage {
    .init(data: data.map(\.post), nextId: nextId)
  }
}

struct CommunityReplyResponse: Decodable {
  let reply: CommunityReply

  private enum CodingKeys: String, CodingKey { case type, post, thread }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    switch try values.decode(String.self, forKey: .type) {
    case "single":
      reply = .single(try values.decode(CommunityPostResponse.self, forKey: .post).post)
    case "thread":
      let posts = try values.decode([CommunityPostResponse].self, forKey: .thread).map(\.post)
      guard !posts.isEmpty else {
        throw DecodingError.dataCorruptedError(forKey: .thread, in: values, debugDescription: "Empty reply thread")
      }
      reply = .thread(posts)
    default:
      throw DecodingError.dataCorruptedError(forKey: .type, in: values, debugDescription: "Unknown reply type")
    }
  }
}

struct CommunityReplyPageResponse: Decodable {
  let data: [CommunityReplyResponse]
  let nextId: String?

  var page: CommunityReplyPage {
    .init(data: data.map(\.reply), nextId: nextId)
  }
}

struct CommunityPostDetailsResponse: Decodable {
  let post: CommunityPostResponse
  let upstream: [CommunityPostResponse]
  let replies: CommunityReplyPageResponse

  var details: CommunityPostDetails {
    .init(post: post.post, upstream: upstream.map(\.post), replies: replies.page)
  }
}
