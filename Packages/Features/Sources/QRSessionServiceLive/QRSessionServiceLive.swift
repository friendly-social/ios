import AVFoundation
import CameraPermissionService
import QRSessionService

actor QRSessionServiceLive {
  private let permission: CameraPermissionService

  init(permission: CameraPermissionService) {
    self.permission = permission
  }

  func makeSession(
    delegate: AVCaptureMetadataOutputObjectsDelegate
  ) async throws -> QRSessionConfiguration {
    switch permission.status() {
    case .authorized: break
    case .notDetermined:
      guard await permission.request() else { throw CameraSessionError.permissionDenied }
    case .denied, .restricted:
      throw CameraSessionError.permissionDenied
    }
    try Task.checkCancellation()
    let session = AVCaptureSession()
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = .high
    guard let device = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
    ).devices.first else { throw CameraSessionError.noBackCamera }
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else { throw CameraSessionError.cannotAddInput }
    session.addInput(input)
    let metadataOutput = AVCaptureMetadataOutput()
    guard session.canAddOutput(metadataOutput) else { throw CameraSessionError.cannotAddOutput }
    session.addOutput(metadataOutput)
    metadataOutput.setMetadataObjectsDelegate(delegate, queue: .main)
    metadataOutput.metadataObjectTypes = [.qr]
    return .init(session: session, hasTorch: device.hasTorch)
  }

  func startRunning(_ session: AVCaptureSession) {
    if !session.isRunning { session.startRunning() }
  }

  func setTorch(_ session: AVCaptureSession, enabled: Bool) throws -> Bool {
    guard let input = session.inputs.first as? AVCaptureDeviceInput,
          input.device.hasTorch, input.device.isTorchAvailable else { return false }
    try input.device.lockForConfiguration()
    defer { input.device.unlockForConfiguration() }
    input.device.torchMode = enabled ? .on : .off
    return input.device.torchMode == .on
  }

  func stopRunning(_ session: AVCaptureSession) {
    if session.isRunning { session.stopRunning() }
  }
}
