import Foundation
import Models

struct AuthResponse: Decodable {
  let token: String
  let id: Int64
  let accessHash: String

  func authorization() throws -> Authorization {
    Authorization(
      token: try Token(token), id: UserId(id),
      accessHash: try UserAccessHash(accessHash))
  }
}

struct FileDTO: Encodable {
  let id: Int64
  let accessHash: String

  init(_ descriptor: FileDescriptor) {
    id = descriptor.id.int64
    accessHash = descriptor.accessHash.string
  }
}

struct GenerateBody: Encodable {
  let nickname: String
  let description: String
  let interests: [String]
  let avatar: FileDTO?
  let socialLink: String?

  enum CodingKeys: String, CodingKey {
    case nickname, description, interests, avatar, socialLink
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(nickname, forKey: .nickname)
    try container.encode(description, forKey: .description)
    try container.encode(interests, forKey: .interests)
    try container.encode(avatar, forKey: .avatar)
    try container.encode(socialLink, forKey: .socialLink)
  }
}

struct EmailBody: Encodable { let email: String }
struct LoginBody: Encodable { let email: String; let code: Int }
struct ConfirmBody: Encodable { let code: Int }
