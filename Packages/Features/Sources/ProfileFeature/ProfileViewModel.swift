import Dependencies
import FriendlyUIKit
import Models
import ProfileFormService
import ProfileService
import SwiftUI

@MainActor
@Observable
class ProfileViewModel {
    @ObservationIgnored @Dependency(ProfileFormService.self) var profileFormService
    @ObservationIgnored @Dependency(ProfileService.self) private var service
    private let router: Router
    private let mode: ProfileView.Mode

    private var selfProfile: ProfileView.SelfProfile {
        guard case let .selfProfile(result) = mode else {
            fatalError("expected self profile")
        }
        return result
    }
    private var otherProfile: ProfileView.OtherProfile {
        guard case let .otherProfile(result) = mode else {
            fatalError("expected other profile")
        }
        return result
    }

    var enableSignOut: Bool { if case .selfProfile = mode { true } else { false } }
    var enableRemoveFromFriends: Bool { if case .otherProfile = mode { true } else { false } }
    var shouldEditProfile: Bool = false

    func showEditProfile() {
        shouldEditProfile = true
    }

    init(router: Router, mode: ProfileView.Mode) {
        self.router = router
        self.mode = mode
    }

    private var reloadTask: Task<Void, Never>?

    private(set) var state: State = .loading
    private(set) var alertError: AlertError? = nil

    var success: ProfileInfo {
        get {
            guard case let .success(success) = state else {
                fatalError("expected success")
            }
            return success
        }
    }

    var socialLinkDestination: URL? {
        guard case let .success(profile) = state,
              let url = profile.socialUrl else { return nil }
        guard url.scheme == nil else { return url }
        return URL(string: "https://\(url.absoluteString)")
    }

    func appear() {
        startReload()
    }

    func editProfileDismissed() {
        startReload()
    }

    func reload() async {
        let task = makeReloadTask()
        await task.value
    }

    private func startReload() {
        makeReloadTask()
    }

    @discardableResult
    private func makeReloadTask() -> Task<Void, Never> {
        reloadTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            _ = await self?.performReload()
        }
        reloadTask = task
        return task
    }

    private func performReload() async {
        do {
            let selection: ProfileSelection = switch mode {
            case .selfProfile: .current
            case let .otherProfile(other): .other(id: other.id, accessHash: other.accessHash)
            }
            guard let profile = try await service.loadProfile(selection) else { return }
            state = .success(profile)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .ioError
        }
    }

    func signOut() {
        reloadTask?.cancel()
        service.signOut()
        selfProfile.routeToSignUp()
    }

    func friendsDecline() {
        let profile = otherProfile
        Task {
            do {
                try await service.declineFriend(profile.id, profile.accessHash)
                await MainActor.run {
                    router.path.removeLast()
                }
            } catch {
                alertError = .decline
            }
        }
    }

    func clearAlertError() {
        alertError = nil
    }

    enum State {
        case loading
        case success(ProfileInfo)
        case ioError

        var rawValue: Int {
            return switch self {
            case .loading: 0
            case .ioError: 1
            case .success: 2
            }
        }
    }

    enum AlertError {
        case decline
    }
}
