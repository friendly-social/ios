import Foundation
import SwiftUI

@Observable
class SignUpViewModel {
    private let networkClient: NetworkClient = .meetacy

    var nickname: String = "" {
        didSet { validate(reason: .nickname) }
    }
    var description: String = "" {
        didSet { validate(reason: .description) }
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
    var avatarDescriptor: FileDescriptor? = nil
    var loading: Bool = false
    var error: Error? = nil

    var signUpButtonDisabled: Bool {
        get { return uploading }
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
                }
            } catch {
                self.error = .ioError
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
        Task {
            loading = true
            defer { loading = false }
            let authorization = try? await networkClient.authGenerate(
                nickname: try! Nickname(nickname),
                description: try! UserDescription(description),
                interests: Array(pickedInterests),
                avatar: avatarDescriptor,
            )
            if let authorization = authorization {
                print("\(authorization)")
            } else {
                error = .ioError
            }
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

    enum ValidateReason {
        case nickname
        case description
        case signUp
    }

    enum Error {
        case required
        case nicknameMaxLength
        case descriptionMaxLength
        case ioError
    }
}
