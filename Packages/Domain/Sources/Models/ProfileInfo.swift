//
//  ProfileInfo.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import Foundation

public struct ProfileInfo: Sendable {
    public let avatarUrl: URL?
    public let nickname: Nickname
    public let description: UserDescription
    public let interests: [Interest]
    public let socialUrl: URL?
    public let email: String?

    public init(
        avatarUrl: URL?, nickname: Nickname, description: UserDescription,
        interests: [Interest], socialUrl: URL?, email: String?
    ) {
        self.avatarUrl = avatarUrl
        self.nickname = nickname
        self.description = description
        self.interests = interests
        self.socialUrl = socialUrl
        self.email = email
    }
}
