import Foundation

@MainActor
final class AddFriendService {
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy
    private let userDefaults: UserDefaults = .standard
    private let reconciliationUserIdKey = "friends.add.reconciliationUserId"
    private var isAddingFriend: Bool = false

    func add(_ command: AddFriendCommand) async throws(AddError) {
        guard !isAddingFriend else { throw .alreadyProcessing }
        isAddingFriend = true
        defer { isAddingFriend = false }

        let authorization: Authorization
        do {
            authorization = try storage.loadAuthorization()
        } catch {
            throw .retryable
        }

        markForReconciliation(authorization: authorization)

        do {
            try await networkClient.friendsAdd(
                authorization: authorization,
                token: command.token,
                id: command.id,
            )
        } catch let error {
            switch error {
            case .expiredToken:
                clearReconciliation()
                throw .invalidInvite
            case .serverError(let statusCode):
                if (400..<500).contains(statusCode) {
                    clearReconciliation()
                    throw .invalidInvite
                }
                throw .retryable
            case .unauthorized:
                clearReconciliation()
                throw .retryable
            case .ioError:
                throw .retryable
            }
        }

        do {
            try storage.addFriend()
            clearReconciliation()
        } catch {
            // The server operation succeeded. Reconcile the local gate on next launch.
        }
    }

    func hasPendingReconciliation(
        authorization: Authorization,
    ) -> Bool {
        guard let userId = userDefaults.string(
            forKey: reconciliationUserIdKey,
        ) else {
            return false
        }

        guard userId == String(authorization.id.int64) else {
            clearReconciliation()
            return false
        }
        return true
    }

    func reconcile() async throws(ReconciliationError) -> Bool {
        let authorization: Authorization
        do {
            authorization = try storage.loadAuthorization()
        } catch {
            throw .retryable
        }

        let network: NetworkDetails
        do {
            network = try await networkClient.networkDetails(
                authorization: authorization,
            )
        } catch {
            throw .retryable
        }

        guard !network.friends.isEmpty else {
            clearReconciliation()
            return false
        }

        do {
            try storage.addFriend()
            clearReconciliation()
        } catch {
            // Keep the marker and retry persistence on the next launch.
        }
        return true
    }

    func clearReconciliation() {
        userDefaults.removeObject(forKey: reconciliationUserIdKey)
    }

    private func markForReconciliation(
        authorization: Authorization,
    ) {
        userDefaults.set(
            String(authorization.id.int64),
            forKey: reconciliationUserIdKey,
        )
    }

    enum AddError: Swift.Error {
        case alreadyProcessing
        case invalidInvite
        case retryable
    }

    enum ReconciliationError: Swift.Error {
        case retryable
    }

    static let shared = AddFriendService()
}
