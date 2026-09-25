import Dependencies
import DiscoveryFeedService
import FriendlyUIKit
import Models
import SwiftUI

@MainActor
@Observable
class FeedViewModel {
    @ObservationIgnored @Dependency(DiscoveryFeedService.self) private var service

    var state: State = .loading

    let router: Router

    init(router: Router) {
        self.router = router
    }

    func appear() {
        Task {
            await reload()
        }
    }

    private func reload() async {
        do {
            let candidates = try await service.loadCandidates()
            let entries = candidates.map { entry in
                let commonFriends: [CommonFriend] = entry.commonFriends
                    .map { friend in
                        return CommonFriend(
                            id: friend.id,
                            avatarUrl: friend.avatarURL,
                            onClick: { [weak self] in
                                guard let self = self else { return }
                                self.router.path.append(
                                    ProfileDestination(
                                        id: friend.id,
                                        accessHash: friend.accessHash,
                                    )
                                )
                            },
                        )
                    }
                return Entry(
                    id: entry.id,
                    avatarUrl: entry.avatarURL,
                    nickname: entry.nickname,
                    description: entry.description,
                    interests: entry.interests,
                    commonFriends: commonFriends,
                    isRequest: entry.isRequest,
                    isExtendedNetwork: entry.isExtendedNetwork,
                    onLike: { [weak self] in
                        guard let self = self else { return }
                        self.onLike(
                            id: entry.id,
                            accessHash: entry.accessHash,
                        )
                    },
                    onDislike: { [weak self] in
                        guard let self = self else { return }
                        self.onDislike(
                            id: entry.id,
                            accessHash: entry.accessHash,
                        )
                    },
                )
            }
            state = .success(entries)
        } catch {
            state = .ioError
        }
    }

    private func onLike(
        id: UserId,
        accessHash: UserAccessHash,
    ) {
        guard case .success(var entries) = state else {
            fatalError("Can't call onLike when state is not success")
        }
        entries.removeAll { entry in entry.id == id }
        state = .success(entries)
        Task {
            // Ignore all failures as they are not really important.
            // Worst case scenario is that user will see again some of the
            // people they already have seen.
            // UI for the error might be worse than this side-effect.
            try? await service.requestFriend(id, accessHash)
        }
    }

    private func onDislike(
        id: UserId,
        accessHash: UserAccessHash,
    ) {
        guard case .success(var entries) = state else {
            fatalError("Can't call onLike when state is not success")
        }
        entries.removeAll { entry in entry.id == id }
        state = .success(entries)
        Task {
            // Ignore all failures as they are not really important.
            // Worst case scenario is that user will see again some of the
            // people they already have seen.
            // UI for the error might be worse than this side-effect.
            try? await service.declineFriend(id, accessHash)
        }
    }

    enum State {
        case loading
        case ioError
        case success([Entry])

        var rawValue: Int {
            return switch self {
            case .loading: 0
            case .ioError: 1
            case .success: 2
            }
        }
    }

    struct Entry {
        let id: UserId
        let avatarUrl: URL?
        let nickname: Nickname
        let description: UserDescription
        let interests: [Interest]
        let commonFriends: [CommonFriend]
        let isRequest: Bool
        let isExtendedNetwork: Bool
        let onLike: () -> Void
        let onDislike: () -> Void
    }

    struct CommonFriend {
        let id: UserId
        let avatarUrl: URL
        let onClick: () -> Void
    }

    struct ProfileDestination: Hashable {
        let id: UserId
        let accessHash: UserAccessHash
    }
}
