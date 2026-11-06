import Dependencies
import InvitationService
import Observation

@MainActor
@Observable
class NetworkQRCodeViewModel {
  @ObservationIgnored @Dependency(InvitationService.self) private var service

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
        let invitation = try await service.generateInvitation(false)
        state = .success(invitation)
      } catch {
        state = .ioError
      }
    }
  }

  enum State {
    case loading
    case ioError
    case success(InvitationCode)

    var rawValue: Int {
      return switch self {
      case .loading: 0
      case .ioError: 1
      case .success: 2
      }
    }
  }
}
