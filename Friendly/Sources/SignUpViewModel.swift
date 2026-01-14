import Foundation
import SwiftUI

@MainActor
@Observable
class SignUpViewModel {
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

    var signUpButtonDisabled: Bool {
        get { return uploading }
    }

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func upload(_ data: Data) {
        Task {
            uploading = true
            defer { uploading = false }
            do {
                if let compressed = compress(data) {
                    avatarDescriptor = try await networkClient.filesUpload(
                        data: compressed,
                    )
                } else {
                    self.error = .ioError
                    clearImage = true
                }
            } catch {
                self.error = .ioError
                clearImage = true
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

    func clickSignUp() {
        if !validate(reason: .signUp) { return }
        let nickname = try! Nickname(nickname)
        let description = try! UserDescription(description)
        let socialLink = try! SocialLink(socialLink)
        let interests = Array(pickedInterests)
        loading = true
        Task {
            let authorization = try? await networkClient.authGenerate(
                nickname: nickname,
                description: description,
                interests: interests,
                avatar: avatarDescriptor,
                socialLink: socialLink,
            )
            if let authorization = authorization,
               let _ = try? storage.saveAuthorization(authorization) {
                onComplete()
            } else {
                error = .ioError
            }
            loading = false
        }
    }

    func clearError() {
        error = nil
    }

    @discardableResult
    private func validate(reason: ValidateReason) -> Bool {
        return validateNickname(reason) && validateDescription(reason)
    }

    private func validateNickname(_ reason: ValidateReason) -> Bool {
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
        error = nil
        return true
    }

    private func validateDescription(_ reason: ValidateReason) -> Bool {
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
        error = nil
        return true
    }

    private func validateSocialLink(_ reason: ValidateReason) -> Bool {
        if socialLink.isEmpty { return true }
        if socialLink.count > SocialLink.maxLength {
            if reason == .socialLink {
                error = .socialLinkMaxLength
            }
            return false
        }
        error = nil
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
        case ioError
    }
}
