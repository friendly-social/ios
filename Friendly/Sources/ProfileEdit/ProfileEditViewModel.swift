//
//  ProfileEditViewModel.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class ProfileEditViewModel {
    private let onComplete: () -> Void
    private let networkClient: NetworkClient = .meetacy
    private let storage: Storage = .shared

    var nickname: String = "" {
        didSet { validate(reason: .nickname) }
    }
    var description: String = "" {
        didSet { validate(reason: .description) }
    }
    var socialLink: String = "" {
        didSet { validate(reason: .socialLink) }
    }
    let interests: [Interest] = [
        try! Interest("apples"),
        try! Interest("coding"),
        try! Interest("cookies"),
        try! Interest("travel"),
        try! Interest("phronology"),
        try! Interest("neovim"),
        try! Interest("cats"),
        try! Interest("rust"),
        try! Interest("books"),
        try! Interest("procrastination"),
        try! Interest("chinese tea"),
        try! Interest("coffee"),
        try! Interest("sport"),
    ]
    var pickedInterests: Set<Interest> = []

    var uploading: Bool = false
    var clearImage: Bool = false
    var avatarDescriptor: FileDescriptor? = nil
    var loading: Bool = false
    var error: Error? = nil
    var profileInfo: ProfileInfo

    var saveButtonDisabled: Bool {
        get { return uploading }
    }

    private var uploadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init(
        profileInfo: ProfileInfo,
        onComplete: @escaping () -> Void
    ) {
        self.profileInfo = profileInfo
        self.nickname = profileInfo.nickname.string
        self.description = profileInfo.description.string
        self.socialLink = profileInfo.socialUrl.map(\.absoluteString) ?? ""
        self.pickedInterests = Set(profileInfo.interests)
        self.onComplete = onComplete
    }
    
    func dismiss() {
        uploadTask?.cancel()
        saveTask?.cancel()
        onComplete()
    }

    func upload(_ data: Data) {
        uploadTask?.cancel()

        uploadTask = Task { [weak self] in
            self?.uploading = true
            defer { self?.uploading = false }
            
            do {
                try Task.checkCancellation()
                
                guard let compressed = self?.compress(data) else {
                    self?.error = .ioError
                    self?.clearImage = true
                    return
                }
                
                let descriptor = try await self?.networkClient.filesUpload(data: compressed)
                
                try Task.checkCancellation()
                self?.avatarDescriptor = descriptor
            } catch {
                self?.error = .ioError
                self?.clearImage = true
            }
        }
    }

    private func compress(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = image.resize(maxDimension: 256)
        return resized.jpegData(compressionQuality: 0.7)
    }

    func toggle(interest: Interest) {
        if pickedInterests.contains(interest) {
            pickedInterests.remove(interest)
        } else {
            pickedInterests.insert(interest)
        }
    }

    func clicksave() {
        if !validate(reason: .save) { return }
        
        saveTask?.cancel()
        loading = true
        
        let nickname = try! Nickname(nickname)
        let description = try! UserDescription(description)
        let socialLink = encodeSocialLink()
        let interests = Array(pickedInterests)
        let avatar = avatarDescriptor
        
        saveTask = Task { [weak self] in
            defer { self?.loading = false }
            
            do {
                try Task.checkCancellation()
                
                guard let authorization = try self?.storage.loadAuthorization() else {
                    self?.error = .ioError
                    return
                }
                try await self?.networkClient.usersEdit(
                    authorization: authorization,
                    nickname: nickname,
                    description: description,
                    interests: interests,
                    avatar: avatar,
                    socialLink: socialLink
                )
                
                try Task.checkCancellation()
                self?.dismiss()
            } catch {
                self?.error = .ioError
            }
        }
    }

    func encodeSocialLink() -> SocialLink? {
        if socialLink.isEmpty { return nil }
        guard let socialLinkEncoded = URL(
            string: socialLink,
            encodingInvalidCharacters: true,
        )?.absoluteString else { return nil }
        return try? SocialLink(socialLinkEncoded)
    }

    func clearError() {
        error = nil
    }

    @discardableResult
    private func validate(reason: ValidateReason) -> Bool {
        return validateNickname(reason) &&
            validateSocialLink(reason) &&
            validateDescription(reason)
    }

    private func validateNickname(_ reason: ValidateReason) -> Bool {
        guard reason == .nickname || reason == .save else {
            return true
        }
        if nickname.isEmpty {
            if reason == .save {
                error = .required
            }
            return false
        }
        if nickname.count > Nickname.maxLength {
            if reason == .save {
                error = .nicknameMaxLength
            }
            return false
        }
        return true
    }

    private func validateDescription(_ reason: ValidateReason) -> Bool {
        guard reason == .description || reason == .save else {
            return true
        }
        if description.isEmpty {
            if reason == .save {
                error = .required
            }
            return false
        }
        if description.count > UserDescription.maxLength {
            if reason == .save {
                error = .descriptionMaxLength
            }
            return false
        }
        return true
    }

    private let socialLinkRegex =
        try! Regex("((http|https):\\/\\/)?\\w+\\.\\w+.*")

    private func validateSocialLink(_ reason: ValidateReason) -> Bool {
        guard reason == .socialLink || reason == .save else {
            return true
        }
        if socialLink.isEmpty { return true }
        if socialLink.count > SocialLink.maxLength {
            if reason == .save {
                error = .socialLinkMaxLength
            }
            return false
        }
        guard let _ = try? socialLinkRegex.wholeMatch(in: socialLink) else {
            if reason == .save {
                error = .socialLinkNotUrl
            }
            return false
        }
        return true
    }

    enum ValidateReason {
        case nickname
        case description
        case socialLink
        case save
    }

    enum Error {
        case required
        case nicknameMaxLength
        case descriptionMaxLength
        case socialLinkMaxLength
        case socialLinkNotUrl
        case ioError
    }
}
