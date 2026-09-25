//
//  ProfileEditViewModel.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import Foundation
import ProfileFormService
import Models
import PhotosUI
import SwiftUI

@MainActor
@Observable
class ProfileEditViewModel {
    private let onComplete: () -> Void
    private let service: ProfileFormService

    var nickname: String = "" {
        didSet { validate(reason: .nickname) }
    }
    var description: String = "" {
        didSet { validate(reason: .description) }
    }
    var socialLink: String = "" {
        didSet { validate(reason: .socialLink) }
    }
    var email: String?
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
    var previewAvatarData: Data? = nil
    var loading: Bool = false
    var isUnlinkingEmail: Bool = false
    var error: Error? = nil
    var profileInfo: ProfileInfo

    var saveButtonDisabled: Bool {
        uploading || isUnlinkingEmail
    }

    private var uploadTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var unlinkEmailTask: Task<Void, Never>?

    init(
        profileInfo: ProfileInfo,
        onComplete: @escaping () -> Void,
        service: ProfileFormService
    ) {
        self.profileInfo = profileInfo
        self.nickname = profileInfo.nickname.string
        self.description = profileInfo.description.string
        self.socialLink = profileInfo.socialUrl.map(\.absoluteString) ?? ""
        self.email = profileInfo.email
        self.pickedInterests = Set(profileInfo.interests)
        self.onComplete = onComplete
        self.service = service
    }
    
    func dismiss() {
        cancelTasks()
        onComplete()
    }

    func cancelTasks() {
        selectionTask?.cancel()
        uploadTask?.cancel()
        saveTask?.cancel()
        unlinkEmailTask?.cancel()
    }

    func emailLinked(_ email: String) {
        self.email = email
    }

    func unlinkEmail() {
        guard email != nil, !isUnlinkingEmail else { return }
        unlinkEmailTask?.cancel()
        unlinkEmailTask = Task { [weak self] in
            self?.isUnlinkingEmail = true
            defer { self?.isUnlinkingEmail = false }

            do {
                try await self?.service.unlinkEmail()
                try Task.checkCancellation()
                self?.email = nil
            } catch is CancellationError {
                return
            } catch {
                self?.error = .ioError
            }
        }
    }

    func upload(_ data: Data) {
        uploadTask?.cancel()

        uploadTask = Task { [weak self] in
            self?.uploading = true
            defer { self?.uploading = false }
            
            do {
                try Task.checkCancellation()
                
                let descriptor = try await self?.service.uploadAvatar(data)
                
                try Task.checkCancellation()
                self?.avatarDescriptor = descriptor
            } catch {
                self?.error = .ioError
                self?.clearImage = true
                self?.previewAvatarData = nil
            }
        }
    }

    func selectAvatar(_ item: PhotosPickerItem?) {
        selectionTask?.cancel()
        guard let item else { return }
        selectionTask = Task { [weak self] in
            do {
                guard let data = try await self?.service.loadAvatar(item) else { return }
                try Task.checkCancellation()
                self?.previewAvatarData = data
                self?.upload(data)
            } catch is CancellationError {
                return
            } catch {
                self?.error = .ioError
                self?.clearImage = true
                self?.previewAvatarData = nil
            }
        }
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
                
                try await self?.service.updateProfile(
                    nickname,
                    description,
                    interests,
                    avatar,
                    socialLink
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
