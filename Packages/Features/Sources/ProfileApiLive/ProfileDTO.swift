import Foundation
import Models

struct UserDetailsDTO: Decodable {
  let id: Int64
  let accessHash: String
  let nickname: String
  let description: String
  let interests: [String]
  let avatar: ProfileFileDTO?
  let socialLink: String?
  let email: String?

  func userDetails() throws -> UserDetails {
    UserDetails(
      id: UserId(id), accessHash: try UserAccessHash(accessHash),
      nickname: try Nickname(nickname), description: try UserDescription(description),
      interests: try interests.map(Interest.init), avatar: try avatar?.descriptor(),
      socialLink: try socialLink.map(SocialLink.init), email: email)
  }
}

struct ProfileFileDTO: Codable {
  let id: Int64
  let accessHash: String

  init(_ descriptor: FileDescriptor) {
    id = descriptor.id.int64
    accessHash = descriptor.accessHash.string
  }

  func descriptor() throws -> FileDescriptor {
    FileDescriptor(id: FileId(id), accessHash: try FileAccessHash(accessHash))
  }
}

struct UserEditBody: Encodable {
  let nickname: Field<String>
  let description: Field<String>
  let interests: Field<[String]>
  let socialLink: Field<String?>
  let avatar: Field<ProfileFileDTO?>?

  init(
    nickname: String,
    description: String,
    interests: [String],
    avatar: ProfileFileDTO?,
    socialLink: String?
  ) {
    self.nickname = Field(value: nickname)
    self.description = Field(value: description)
    self.interests = Field(value: interests)
    self.socialLink = Field(value: socialLink)
    self.avatar = avatar.map { Field(value: Optional($0)) }
  }
}

struct Field<Value: Encodable>: Encodable { let value: Value }
