import Dependencies
import Foundation
import FriendlyUIKit
import Models
import NetworkService
import Observation

@MainActor
@Observable
class NetworkViewModel {
  @ObservationIgnored @Dependency(NetworkService.self) private var service

  var state: State = .loading
  var destination: Destination?

  let router: Router

  private var reloadGeneration: Int = 0

  init(router: Router) {
    self.router = router
  }

  func showQRCode() {
    destination = .qrCode
  }

  func findQRCode() {
    destination = .scanner
  }

  func reload() async {
    reloadGeneration &+= 1
    let generation = reloadGeneration
    do {
      let friends = try await service.loadFriends()
      guard
        !Task.isCancelled,
        generation == reloadGeneration
      else {
        return
      }
      state = .success(mapUsers(friends))
    } catch {
      guard
        !Task.isCancelled,
        generation == reloadGeneration
      else {
        return
      }
      state = .ioError
    }
  }

  enum State {
    case loading
    case ioError
    case success([Friend])

    var rawValue: Int {
      switch self {
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

  enum Destination: Hashable, Identifiable {
    case qrCode
    case scanner
    case profile(id: UserId, accessHash: UserAccessHash)

    var id: Self { self }
  }
}

private extension NetworkViewModel {
  private func mapUsers(_ users: [NetworkFriend]) -> [Friend] {
    users.map { user in
      Friend(
        id: user.id,
        avatarUrl: user.avatarURL,
        nickname: user.nickname,
        onClick: { [weak self] in
          guard let self = self else { return }
          let destination = Destination.profile(
            id: user.id,
            accessHash: user.accessHash
          )
          self.router.path.append(destination)
        }
      )
    }
  }
}
