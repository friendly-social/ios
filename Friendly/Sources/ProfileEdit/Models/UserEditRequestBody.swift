//
//  UserEditRequestBody.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import Foundation

struct UserEditRequestBody: Encodable {
    let nickname: Value<String>
    let description: Value<String>
    let interests: Value<[String]>
    let socialLink: Value<String?>
    let avatar: Value<FileDescriptorSerializable?>

    enum CodingKeys: String, CodingKey {
        case nickname
        case description
        case interests
        case socialLink
        case avatar
    }
}

struct Value<T: Encodable>: Encodable {
    let value: T
}

extension UserEditRequestBody {
    init(
        nickname: String,
        description: String,
        interests: [String],
        avatar: FileDescriptorSerializable?,
        socialLink: String?
    ) {
        self.nickname = .init(value: nickname)
        self.description = .init(value: description)
        self.interests = .init(value: interests)
        self.avatar = .init(value: avatar)
        self.socialLink = .init(value: socialLink)
    }
}
