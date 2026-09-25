import AccountStorageService
import AddFriendService
import Dependencies
import Foundation
import FriendsApi
import Models
import Synchronization

struct AddFriendServiceLive: Sendable {
    @Dependency(AccountStorageService.self) private var storage
    @Dependency(FriendsApi.self) private var friendsApi
    private var userDefaults: UserDefaults { .standard }
    private let reconciliationUserIdKey = "friends.add.reconciliationUserId"
    private static let isAddingFriend = Mutex(false)

    func add(_ command: AddFriendCommand) async throws(AddFriendService.AddError) {
        guard Self.isAddingFriend.withLock({ value in
            guard !value else { return false }
            value = true
            return true
        }) else { throw .alreadyProcessing }
        defer { Self.isAddingFriend.withLock { $0 = false } }

        let authorization: Authorization
        do {
            authorization = try storage.loadAuthorization()
        } catch {
            throw .retryable
        }

        markForReconciliation(authorization: authorization)

        do {
            try await friendsApi.friendsAdd(
                authorization,
                command.token,
                command.id,
            )
        } catch let error as FriendsApi.Error {
            switch error {
            case .expiredToken:
                clearReconciliation()
                throw .invalidInvite
            case let .serverError(statusCode):
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
        } catch {
            throw .retryable
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

    func reconcile() async throws(AddFriendService.ReconciliationError) -> Bool {
        let authorization: Authorization
        do {
            authorization = try storage.loadAuthorization()
        } catch {
            throw .retryable
        }

        let network: NetworkDetails
        do {
            network = try await friendsApi.networkDetails(authorization)
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
}
