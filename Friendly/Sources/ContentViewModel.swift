import SwiftUI

@MainActor
@Observable
class ContentViewModel {
    private(set) var destination: Destination = .empty
    private let storage: Storage = .shared
    private let addFriendService: AddFriendService = .shared
    private var activeInvite: ActiveInvite?

    private(set) var isProcessingFriendAccess: Bool = false
    var friendLinkAlert: FriendLinkAlert?
    var mainRoute: MainRoute?

    func appear() {
        guard !isProcessingFriendAccess else { return }

        do {
            if try storage.hasAuthorization() {
                let authorization = try storage.loadAuthorization()
                if addFriendService.hasPendingReconciliation(
                    authorization: authorization,
                ) {
                    reconcileFriendAccess()
                } else {
                    routeUsingStoredFriendState()
                }
            } else {
                destination = .signUp
            }
        } catch {
            storage.clearAuthorization()
            destination = .signUp
        }
    }

    func onSignUp() {
        destination = .qrAddFriend
    }

    func onAddFriendWithQr() {
        mainRoute = .feed
        destination = .main
    }

    func onEmailLogin() {
        try? storage.addFriend()
        addFriendService.clearReconciliation()
        mainRoute = .feed
        destination = .main
    }

    func routeToSignUp() {
        activeInvite = nil
        mainRoute = nil
        addFriendService.clearReconciliation()
        appear()
    }

    func onAddFriend(id: UserId, token: FriendToken) {
        guard !isProcessingFriendAccess else {
            friendLinkAlert = .alreadyProcessing
            return
        }
        guard activeInvite == nil else {
            friendLinkAlert = .retryInvite
            return
        }

        let command = AddFriendCommand(id: id, token: token)

        do {
            guard try storage.hasAuthorization() else {
                destination = .signUp
                friendLinkAlert = .authenticationRequired
                return
            }

            let hasFriend = try storage.getHasFriend()
            destination = hasFriend || destination == .main
                ? .main
                : .qrAddFriend
            activeInvite = ActiveInvite(command: command)
            addActiveInvite()
        } catch {
            storage.clearAuthorization()
            destination = .signUp
            friendLinkAlert = .authenticationRequired
        }
    }

    func onInvalidFriendLink() {
        guard !isProcessingFriendAccess else {
            friendLinkAlert = .alreadyProcessing
            return
        }
        guard activeInvite == nil else {
            friendLinkAlert = .retryInvite
            return
        }
        friendLinkAlert = .invalidInvite
    }

    func retryFriendLink() {
        guard activeInvite != nil else { return }
        addActiveInvite()
    }

    func cancelFriendLink() {
        activeInvite = nil
    }

    func retryFriendAccessReconciliation() {
        reconcileFriendAccess()
    }

    private func addActiveInvite() {
        guard let activeInvite else { return }
        isProcessingFriendAccess = true
        friendLinkAlert = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                try await addFriendService.add(activeInvite.command)
                self.activeInvite = nil
                isProcessingFriendAccess = false
                friendLinkAlert = nil
                mainRoute = .feed
                destination = .main
            } catch let error as AddFriendService.AddError {
                isProcessingFriendAccess = false
                switch error {
                case .alreadyProcessing:
                    self.activeInvite = nil
                    friendLinkAlert = .alreadyProcessing
                case .invalidInvite:
                    self.activeInvite = nil
                    friendLinkAlert = .invalidInvite
                case .retryable:
                    friendLinkAlert = .retryInvite
                }
            }
        }
    }

    private func reconcileFriendAccess() {
        guard !isProcessingFriendAccess else { return }
        isProcessingFriendAccess = true
        friendLinkAlert = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                let hasFriend = try await addFriendService.reconcile()
                isProcessingFriendAccess = false
                friendLinkAlert = nil
                if hasFriend {
                    mainRoute = .feed
                    destination = .main
                } else {
                    destination = .qrAddFriend
                }
            } catch {
                isProcessingFriendAccess = false
                routeUsingStoredFriendState()
                friendLinkAlert = .retryReconciliation
            }
        }
    }

    private func routeUsingStoredFriendState() {
        do {
            destination = try storage.getHasFriend()
                ? .main
                : .qrAddFriend
        } catch {
            storage.clearAuthorization()
            destination = .signUp
        }
    }

    private struct ActiveInvite {
        let command: AddFriendCommand
    }

    enum Destination: Hashable {
        case empty
        case signUp
        case main
        case qrAddFriend
    }

    enum MainRoute: Hashable {
        case feed
    }

    enum FriendLinkAlert: Int, Identifiable {
        case authenticationRequired
        case alreadyProcessing
        case invalidInvite
        case retryInvite
        case retryReconciliation

        var id: Int { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .authenticationRequired:
                .friendLinkAuthRequiredTitle
            case .alreadyProcessing:
                .friendLinkProcessingTitle
            case .invalidInvite:
                .friendLinkInvalidTitle
            case .retryInvite:
                .friendLinkRetryTitle
            case .retryReconciliation:
                .friendGateRetryTitle
            }
        }

        var message: LocalizedStringResource {
            switch self {
            case .authenticationRequired:
                .friendLinkAuthRequiredMessage
            case .alreadyProcessing:
                .friendLinkProcessingMessage
            case .invalidInvite:
                .friendLinkInvalidMessage
            case .retryInvite:
                .friendLinkRetryMessage
            case .retryReconciliation:
                .friendGateRetryMessage
            }
        }
    }
}
