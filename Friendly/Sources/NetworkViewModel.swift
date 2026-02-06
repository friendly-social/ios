import SwiftUI

@MainActor
@Observable
class NetworkViewModel {
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    var state: State = .loading
    var shouldShowQRCode: Bool = false {
        didSet {
            if !shouldShowQRCode {
                Task {
                    await reload()
                }
            }
        }
    }
    var shouldFindQRCode: Bool = false {
        didSet {
            if !shouldFindQRCode {
                Task {
                    await reload()
                }
            }
        }
    }

    let router: Router

    init(router: Router) {
        self.router = router
    }

    func showQRCode() {
        shouldShowQRCode = true
    }

    func findQRCode() {
        shouldFindQRCode = true
    }

    func appear() {
        Task {
            await reload()
        }
    }

    func reload() async {
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

    private func mapUsers(_ users: [UserDetails]) -> [Friend] {
        return users.map { user in
            let avatarUrl: URL? = if let avatar = user.avatar {
                networkClient.filesDownloadUrl(for: avatar)
            } else {
                nil
            }
            return Friend(
                id: user.id,
                avatarUrl: avatarUrl,
                nickname: user.nickname,
                onClick: { [weak self] in
                    guard let self = self else { return }
                    let destination = ProfileDestination(
                        id: user.id,
                        accessHash: user.accessHash,
                    )
                    self.router.path.append(destination)
                }
            )
        }
    }

    func command(addFriend: AddFriendCommand) {
        let id = addFriend.id
        let token = addFriend.token
        Task {
            shouldShowQRCode = false
            guard let authorization = try? storage.loadAuthorization() else {
                return
            }
            guard let _ = try? await networkClient.friendsAdd(
                authorization: authorization,
                token: token,
                id: id,
            ) else { return }
            await reload()
        }
    }

    enum State {
        case loading
        case ioError
        case success([Friend])

        var rawValue: Int {
            return switch self {
            case .loading: 0
            case .ioError: 1
            case .success: 2
            }
        }
    }

    struct Friend {
        let id: UserId
        let avatarUrl: URL?
        let nickname: Nickname
        let onClick: () -> Void
    }

    struct ProfileDestination: Hashable {
        let id: UserId
        let accessHash: UserAccessHash
    }
}
