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
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  private var preparationGeneration = 0
  private let onDismiss: (String?) -> Void

  var settingsURL: URL? { permissionService.settingsURL() }

  init(onDismiss: @escaping (String?) -> Void) {
    self.onDismiss = onDismiss
  }

  func prepare() async {
    guard state != .loading, state != .running else { return }
    preparationGeneration += 1
    let generation = preparationGeneration
    state = .loading
    let qrDelegate = QrScannerDelegate()
    do {
      let configuredSession = try await service.makeSession(qrDelegate)
      guard generation == preparationGeneration, !Task.isCancelled else { return }
      startListening(qrDelegate)
      session = configuredSession
      await service.startRunning(configuredSession)
      guard generation == preparationGeneration, !Task.isCancelled else {
        await service.stopRunning(configuredSession)
        return
      }
      state = .running
    } catch {
      guard generation == preparationGeneration, !Task.isCancelled else { return }
      state = error as? CameraSessionError == .permissionDenied ? .noPermission : .ioError
    }
  }

  func stop() {
    preparationGeneration += 1
    scanTask?.cancel()
    scanTask = nil
    state = .idle
    guard let session else { return }
    self.session = nil
    Task { await service.stopRunning(session) }
  }

  func onDismiss(code: String?) {
    stop()
    onDismiss(code)
  }
}

private extension QRScannerViewModel {
  private func startListening(_ qrDelegate: QrScannerDelegate) {
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
