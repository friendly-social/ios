import SwiftUI

@MainActor
@Observable
class FeedViewModel {
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
                let queue = try await networkClient.feedQueue(
                    authorization: authorization,
                )
                let entries = queue.entries.map { entry in
                    let avatarUrl: URL? = if let avatar = entry.details.avatar {
                        networkClient.filesDownloadUrl(for: avatar)
                    } else {
                        nil
                    }
                    return Entry(
                        id: entry.details.id,
                        avatarUrl: avatarUrl,
                        nickname: entry.details.nickname,
                        description: entry.details.description,
                        interests: entry.details.interests,
                        onLike: { [weak self] in
                            guard let self = self else { return }
                            self.onLike(
                                authorization: authorization,
                                id: entry.details.id,
                                accessHash: entry.details.accessHash,
                            )
                        },
                        onDislike: { [weak self] in
                            guard let self = self else { return }
                            self.onDislike(
                                authorization: authorization,
                                id: entry.details.id,
                                accessHash: entry.details.accessHash,
                            )
                        },
                    )
                }
                state = .success(entries)
            } catch {
                state = .ioError
            }
        }
    }

    private func onLike(
        authorization: Authorization,
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
            try? await networkClient.friendsRequest(
                authorization: authorization,
                id: id,
                accessHash: accessHash,
            )
        }
    }

    private func onDislike(
        authorization: Authorization,
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
            try? await networkClient.friendsDecline(
                authorization: authorization,
                id: id,
                accessHash: accessHash,
            )
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
        let onLike: () -> Void
        let onDislike: () -> Void
    }
}
