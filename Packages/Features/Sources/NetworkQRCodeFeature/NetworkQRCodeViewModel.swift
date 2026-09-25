import Dependencies
import NetworkService
import SwiftUI

@MainActor
@Observable
class NetworkQRCodeViewModel {
    @ObservationIgnored @Dependency(NetworkService.self) private var service

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
                let url = try await service.generateInvitationURL()
                let success = Success(url: url, image: service.generateQRCode(url))
                state = .success(success)
            } catch {
                state = .ioError
            }
        }
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
        let image: UIImage?
    }
}
