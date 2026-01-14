import SwiftUI

@MainActor
@Observable
class NetworkQRCodeViewModel {
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    var state: State = .loading
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var firstAppear = true
    func appear() {
        guard firstAppear else { return }
        firstAppear = false
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                let token = try await networkClient.friendsGenerate(
                    authorization: authorization,
                )
                let url = buildQRUrl(for: authorization.id, with: token)
                let success = Success(url: url)
                state = .success(success)
            } catch {
                state = .ioError
            }
        }
    }

    private func buildQRUrl(
        for userId: UserId,
        with token: FriendToken,
    ) -> URL {
        return URL(string: "friendly://add/\(userId.int64)/\(token.string)")!
    }

    enum State {
        case loading
        case ioError
        case success(Success)

        var rawValue: Int {
            return switch self {
            case .loading: 0
            case .ioError: 1
            case .success: 2
            }
        }
    }

    struct Success {
        let url: URL
    }
}

