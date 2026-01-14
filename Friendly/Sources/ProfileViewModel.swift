import SwiftUI

@MainActor
@Observable
class ProfileViewModel {
    private let router: Router
    private let mode: ProfileView.Mode

    private var selfProfile: ProfileView.SelfProfile {
        guard case .selfProfile(let result) = mode else {
            fatalError("expected self profile")
        }
        return result
    }
    private var otherProfile: ProfileView.OtherProfile {
        guard case .otherProfile(let result) = mode else {
            fatalError("expected self profile")
        }
        return result
    }

    let enableSignOut: Bool
    let enableRemoveFromFriends: Bool

    init(
        router: Router,
        mode: ProfileView.Mode,
    ) {
        self.router = router
        self.mode = mode
        self.enableSignOut =
            if case .selfProfile = mode { true } else { false }
        self.enableRemoveFromFriends =
            if case.otherProfile = mode { true } else { false }
    }

    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    private(set) var state: State = .loading
    private(set) var alertError: AlertError? = nil

    private var firstAppear = true
    func appear() {
        guard firstAppear else { return }
        firstAppear = false
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                let id = switch mode {
                case .selfProfile: authorization.id
                case .otherProfile(let otherProfile): otherProfile.id
                }
                let accessHash = switch mode {
                case .selfProfile: authorization.accessHash
                case .otherProfile(let otherProfile): otherProfile.accessHash
                }
                let userDetails = try await networkClient.usersDetails(
                    authorization: authorization,
                    id: id,
                    accessHash: accessHash,
                )
                let url: URL? = if let avatar = userDetails.avatar {
                    networkClient.filesDownloadUrl(for: avatar)
                } else {
                    nil
                }
                let success = Success(
                    avatarUrl: url,
                    nickname: userDetails.nickname,
                    description: userDetails.description,
                    interests: userDetails.interests,
                )
                state = .success(success)
            } catch {
                state = .ioError
            }
        }
    }

    func signOut() {
        storage.clearAuthorization()
        selfProfile.routeToSignUp()
    }

    func friendsDecline() {
        let profile = otherProfile
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                try await networkClient.friendsDecline(
                    authorization: authorization,
                    id: profile.id,
                    accessHash: profile.accessHash,
                )
                await MainActor.run {
                    router.path.removeLast()
                    profile.onFriendsDecline()
                }
            } catch {
                alertError = .decline
            }
        }
    }

    func clearAlertError() {
        alertError = nil
    }

    enum State {
        case loading
        case success(Success)
        case ioError

        var rawValue: Int {
            return switch self {
            case .loading: 0
            case .ioError: 1
            case .success: 2
            }
        }
    }

    enum AlertError {
        case decline
    }

    struct Success {
        let avatarUrl: URL?
        let nickname: Nickname
        let description: UserDescription
        let interests: [Interest]
    }
}
