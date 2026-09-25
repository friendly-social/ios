import Dependencies
import FriendlyUIKit
import Models
import NetworkService
import SwiftUI

@MainActor
@Observable
class NetworkViewModel {
    @ObservationIgnored @Dependency(NetworkService.self) private var service

    var state: State = .loading
    private var reloadGeneration: Int = 0

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

    func reload() async {
        reloadGeneration &+= 1
        let generation = reloadGeneration

        do {
            let friends = try await service.loadFriends()
            guard !Task.isCancelled,
                  generation == reloadGeneration else {
                return
            }
            state = .success(mapUsers(friends))
        } catch {
            guard !Task.isCancelled,
                  generation == reloadGeneration else {
                return
            }
            state = .ioError
        }
    }

    private func mapUsers(_ users: [NetworkFriend]) -> [Friend] {
        return users.map { user in
            return Friend(
                id: user.id,
                avatarUrl: user.avatarURL,
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
