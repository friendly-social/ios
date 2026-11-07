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
  private(set) var isTorchOn = false
  private(set) var hasTorch = false
  @ObservationIgnored private var scanTask: Task<Void, Never>?
  private var preparationGeneration = 0
  private var isChangingTorch = false
  private let acceptsInput: () -> Bool
  private let onCode: (String) -> Void

  var settingsURL: URL? { permissionService.settingsURL() }

  init(acceptsInput: @escaping () -> Bool, onCode: @escaping (String) -> Void) {
    self.acceptsInput = acceptsInput
    self.onCode = onCode
  }

  func prepare() async {
    guard state != .loading, state != .running else { return }
    preparationGeneration += 1
    let generation = preparationGeneration
    state = .loading
    let qrDelegate = QrScannerDelegate()
    do {
      let configuration = try await service.makeSession(qrDelegate)
      guard generation == preparationGeneration, !Task.isCancelled else { return }
      let configuredSession = configuration.session
      startListening(qrDelegate)
      session = configuredSession
      await service.startRunning(configuredSession)
      guard generation == preparationGeneration, !Task.isCancelled else {
        await service.stopRunning(configuredSession)
        return
      }
      hasTorch = configuration.hasTorch
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
    hasTorch = false
    isTorchOn = false
    guard let session else { return }
    self.session = nil
    Task { await service.stopRunning(session) }
  }

  func toggleTorch() async {
    guard let session, !isChangingTorch else { return }
    isChangingTorch = true
    defer { isChangingTorch = false }
    do {
      let enabled = try await service.setTorch(session, !isTorchOn)
      if self.session === session { isTorchOn = enabled }
    } catch {
      return
    }
  }
}

private extension QRScannerViewModel {
  private func startListening(_ qrDelegate: QrScannerDelegate) {
    guard scanTask == nil else { return }
    scanTask = Task { [weak self, qrDelegate] in
      let clock = ContinuousClock()
      var previous: (code: String, time: ContinuousClock.Instant)?
      for await code in qrDelegate.codes {
        guard let self, !Task.isCancelled else { return }
        let now = clock.now
        let isStillVisible = previous.map {
          $0.code == code && now - $0.time < Constants.detectionGap
        } ?? false
        guard isStillVisible || acceptsInput() else { continue }
        previous = (code, now)
        if !isStillVisible { onCode(code) }
      }
    }
  }
}

private enum Constants {
  static let detectionGap: Duration = .seconds(1)
}
