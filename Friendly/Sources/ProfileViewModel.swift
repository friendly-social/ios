import SwiftUI

@Observable
class ProfileViewModel {
    private let routeToSignUp: () -> Void

    init(routeToSignUp: @escaping () -> Void) {
        self.routeToSignUp = routeToSignUp
    }

    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    var state: State = .loading

    private var firstAppear = true
    func appear() {
        guard firstAppear else { return }
        firstAppear = false
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                let userDetails = try await networkClient.usersDetails(
                    authorization: authorization,
                    id: authorization.id,
                    accessHash: authorization.accessHash,
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
        routeToSignUp()
    }

    enum State {
        case loading
        case success(Success)
        case ioError
    }

    struct Success {
        let avatarUrl: URL?
        let nickname: Nickname
        let description: UserDescription
        let interests: [Interest]
    }
}
