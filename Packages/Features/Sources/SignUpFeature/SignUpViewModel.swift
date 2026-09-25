import Foundation
import ProfileFormService
import Models
import PhotosUI
import SwiftUI

@MainActor
@Observable
class SignUpViewModel {
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
    var error: Error? = nil

    var signUpButtonDisabled: Bool {
        get { return uploading }
    }

    init(onComplete: @escaping () -> Void, service: ProfileFormService) {
        self.onComplete = onComplete
        self.service = service
    }

    func upload(_ data: Data) {
        Task {
            uploading = true
            defer { uploading = false }
            do {
                avatarDescriptor = try await service.uploadAvatar(data)
            } catch {
                self.error = .ioError
                clearImage = true
                previewAvatarData = nil
            }
        }
    }

    func selectAvatar(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                let data = try await service.loadAvatar(item)
                previewAvatarData = data
                upload(data)
            } catch {
                self.error = .ioError
                clearImage = true
                previewAvatarData = nil
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

    func clickSignUp() {
        if !validate(reason: .signUp) { return }
        let nickname = try! Nickname(nickname)
        let description = try! UserDescription(description)
        let socialLink = encodeSocialLink()
        let interests = Array(pickedInterests)
        loading = true
        Task {
            do {
                try await service.signUp(
                nickname,
                description,
                interests,
                avatarDescriptor,
                socialLink,
                )
                onComplete()
            } catch {
                self.error = .ioError
            }
            loading = false
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
        guard reason == .nickname || reason == .signUp else {
            return true
        }
        if nickname.isEmpty {
            if reason == .signUp {
                error = .required
            }
            return false
        }
        if nickname.count > Nickname.maxLength {
            if reason == .signUp {
                error = .nicknameMaxLength
            }
            return false
        }
        return true
    }

    private func validateDescription(_ reason: ValidateReason) -> Bool {
        guard reason == .description || reason == .signUp else {
            return true
        }
        if description.isEmpty {
            if reason == .signUp {
                error = .required
            }
            return false
        }
        if description.count > UserDescription.maxLength {
            if reason == .signUp {
                error = .descriptionMaxLength
            }
            return false
        }
        return true
    }

    private let socialLinkRegex =
        try! Regex("((http|https):\\/\\/)?\\w+\\.\\w+.*")

    private func validateSocialLink(_ reason: ValidateReason) -> Bool {
        guard reason == .socialLink || reason == .signUp else {
            return true
        }
        if socialLink.isEmpty { return true }
        if socialLink.count > SocialLink.maxLength {
            if reason == .signUp {
                error = .socialLinkMaxLength
            }
            return false
        }
        guard let _ = try? socialLinkRegex.wholeMatch(in: socialLink) else {
            if reason == .signUp {
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
        case signUp
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
