import AVFoundation
import CameraPermissionService
import Dependencies
import Foundation
import Observation
import QRSessionService

@MainActor @Observable
final class QRScannerViewModel {
  enum State {
    case idle
    case loading
    case running
    case noPermission
    case ioError
  }

  private(set) var state: State = .idle
  private(set) var session: AVCaptureSession?
  @ObservationIgnored @Dependency(QRSessionService.self) private var service
  @ObservationIgnored @Dependency(CameraPermissionService.self) private var permissionService
  @ObservationIgnored private let qrDelegate = QrScannerDelegate()
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  private let onDismiss: (String?) -> Void

  var settingsURL: URL? { permissionService.settingsURL() }

  init(onDismiss: @escaping (String?) -> Void) {
    self.onDismiss = onDismiss
  }

  func prepare() async {
    guard state != .loading, state != .running else { return }
    state = .loading
    startListening()
    do {
      let configuredSession = try await service.makeSession(qrDelegate)
      guard !Task.isCancelled else { return }
      session = configuredSession
      await service.startRunning(configuredSession)
      guard !Task.isCancelled else { return }
      state = .running
    } catch is CancellationError {
    } catch CameraSessionError.permissionDenied {
      state = .noPermission
    } catch {
      state = .ioError
    }
  }

  func stop() {
    scanTask?.cancel()
    guard let session else { return }
    Task { await service.stopRunning(session) }
  }

  func onDismiss(code: String?) {
    stop()
    onDismiss(code)
  }
}

private extension QRScannerViewModel {
  private func startListening() {
    guard scanTask == nil else { return }
    scanTask = Task { [weak self, qrDelegate] in
      for await code in qrDelegate.codes {
        guard !Task.isCancelled else { return }
        self?.onDismiss(code: code)
        return
      }
    }
  }
}
