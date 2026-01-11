import SwiftUI

@Observable
class NetworkViewModel {
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    var state: State = .loading

    private(set) var shouldShowQRCode: Bool = false

    func showQRCode() {
        shouldShowQRCode = true
    }

    func dismissQRCode(fromButton: Bool) {
        shouldShowQRCode = false
        if !fromButton {
            reload()
        }
    }

    private var firstAppear = true
    func appear() {
        guard firstAppear else { return }
        firstAppear = false
        reload()
    }

    private func reload() {
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                let network = try await networkClient.networkDetails(
                    authorization: authorization,
                )
                let friends = mapUsers(network.friends)
                state = .success(friends)
            } catch {
                state = .ioError
            }
        }
    }

    private func mapUsers(_ users: [UserDetails]) -> [Friend] {
        return users.map { user in
            let avatarUrl: URL? = if let avatar = user.avatar {
                networkClient.filesDownloadUrl(for: avatar)
            } else {
                nil
            }
            return Friend(
                avatarUrl: avatarUrl,
                nickname: user.nickname,
                id: user.id,
                accessHash: user.accessHash,
            )
        }
    }

    enum State {
        case loading
        case success([Friend])
        case ioError
    }

    struct Friend {
        let avatarUrl: URL?
        let nickname: Nickname
        let id: UserId
        let accessHash: UserAccessHash
    }
}
