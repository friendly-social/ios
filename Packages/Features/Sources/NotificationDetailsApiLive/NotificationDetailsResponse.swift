import FilesApi
import Models
import NotificationDetailsApi

struct NotificationDetailsResponse: Decodable {
  let target: NotificationTarget?
  private let details: NotificationDetails
  private let sender: User

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .type) {
    case .newRequest:
      let sender = try container.decode(User.self, forKey: .from)
      let isMutual = try container.decode(Bool.self, forKey: .isMutual)
      details = .friendRequest(nickname: sender.nickname, isMutual: isMutual)
      target = Self.profileTarget(for: sender)
      self.sender = sender
    case .newReply:
      let post = try container.decode(Post.self, forKey: .post)
      guard post.type == .plain else { throw NotificationDetailsError.invalidResponse }
      details = .reply(nickname: post.owner.nickname, text: post.text)
      target = Self.replyTarget(for: post)
      sender = post.owner
    }
  }

  func notification(using files: FilesApi) -> NotificationDetails {
    let image = senderImage(using: files)
    switch details {
    case let .friendRequest(nickname, isMutual, _):
      return .friendRequest(nickname: nickname, isMutual: isMutual, senderImage: image)
    case let .reply(nickname, text, _):
      return .reply(nickname: nickname, text: text, senderImage: image)
    }
  }
}

private extension NotificationDetailsResponse {
  private static func profileTarget(for user: User) -> NotificationTarget? {
    guard let id = user.id, id > 0, let hash = user.accessHash,
          let accessHash = try? UserAccessHash(hash) else { return nil }
    return .profile(id: UserId(id), accessHash: accessHash)
  }

  private static func replyTarget(for post: Post) -> NotificationTarget? {
    guard let id = post.id, id > 0,
          let hash = post.accessHash, !hash.isEmpty else { return nil }
    return .reply(id: id, accessHash: hash)
  }

  private func senderImage(using files: FilesApi) -> NotificationSenderImage? {
    guard let senderID = sender.id, senderID > 0,
          let avatar = sender.avatar, avatar.id > 0,
          let hash = try? FileAccessHash(avatar.accessHash) else { return nil }
    let file = FileDescriptor(id: FileId(avatar.id), accessHash: hash)
    return NotificationSenderImage(senderID: senderID, url: files.downloadURL(for: file))
  }

  private enum CodingKeys: String, CodingKey {
    case type, from, isMutual, post
  }

  private enum Kind: String, Decodable {
    case newRequest = "new_request"
    case newReply = "new_reply"
  }

  private struct User: Decodable {
    let id: Int64?
    let accessHash: String?
    let nickname: String
    let avatar: Avatar?

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try? container.decode(Int64.self, forKey: .id)
      accessHash = try? container.decode(String.self, forKey: .accessHash)
      nickname = try container.decode(String.self, forKey: .nickname)
      avatar = try? container.decode(Avatar.self, forKey: .avatar)
    }

    private enum CodingKeys: String, CodingKey { case id, accessHash, nickname, avatar }
  }

  private struct Avatar: Decodable {
    let id: Int64
    let accessHash: String
  }

  private struct Post: Decodable {
    enum Kind: String, Decodable { case plain, deleted }
    let id: Int64?
    let accessHash: String?
    let type: Kind
    let owner: User
    let text: String
  }
}
