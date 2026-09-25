import Dependencies
import Foundation
import FriendAccessService
import Models
import ProfileFormService
import SwiftUI

@MainActor
@Observable
class ContentViewModel {
    @ObservationIgnored @Dependency(ProfileFormService.self) var profileFormService
    @ObservationIgnored @Dependency(FriendAccessService.self) private var friendAccessService
    private(set) var destination: Destination = .empty
    private var activeInvite: ActiveInvite?

    private(set) var isProcessingFriendAccess: Bool = false
    var friendLinkAlert: FriendLinkAlert?
    var mainRoute: MainRoute?

    func appear() {
        guard !isProcessingFriendAccess else { return }

        do {
            switch try friendAccessService.initialAccess() {
            case .signedOut:
                destination = .signUp
            case .reconcile:
                reconcileFriendAccess()
            case .main:
                destination = .main
            case .addFriend:
                destination = .qrAddFriend
            }
        } catch {
            friendAccessService.invalidateAuthorization()
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

    func open(_ url: URL) {
        guard let deeplink = Deeplink.parseOf(url: url) else {
            onInvalidFriendLink()
            return
        }
        switch deeplink {
        case let .addFriend(id, token):
            onAddFriend(id: id, token: token)
        }
    }

    func onEmailLogin() {
        friendAccessService.completeEmailLogin()
        mainRoute = .community
        destination = .main
    }

    func signOut() {
        friendAccessService.invalidateAuthorization()
        friendAccessService.clearPendingReconciliation()
        activeInvite = nil
        mainRoute = nil
        destination = .signUp
    }

    func routeToSignUp() {
        activeInvite = nil
        mainRoute = nil
        friendAccessService.clearPendingReconciliation()
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
            guard try friendAccessService.hasAuthorization() else {
                destination = .signUp
                friendLinkAlert = .authenticationRequired
                return
            }

            let hasFriend = try friendAccessService.hasFriendAccess()
            destination = hasFriend || destination == .main
                ? .main
                : .qrAddFriend
            activeInvite = ActiveInvite(command: command)
            addActiveInvite()
        } catch {
            friendAccessService.invalidateAuthorization()
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
                try await friendAccessService.addFriend(activeInvite.command)
                self.activeInvite = nil
                isProcessingFriendAccess = false
                friendLinkAlert = nil
                mainRoute = .feed
                destination = .main
            } catch let error as FriendAccessError {
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
            } catch {
                isProcessingFriendAccess = false
                friendLinkAlert = .retryInvite
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
                let hasFriend = try await friendAccessService.reconcileFriendAccess()
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
            destination = try friendAccessService.hasFriendAccess()
                ? .main
                : .qrAddFriend
        } catch {
            friendAccessService.invalidateAuthorization()
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
        case community
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
