//
//  ProfileInfo.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import Foundation

struct ProfileInfo {
    let avatarUrl: URL?
    let nickname: Nickname
    let description: UserDescription
    let interests: [Interest]
    let socialUrl: URL?
}
