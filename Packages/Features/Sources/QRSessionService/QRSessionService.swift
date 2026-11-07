import AVFoundation
import DependenciesMacros

@DependencyClient
public struct QRSessionService: Sendable {
  public var makeSession: @Sendable (
    AVCaptureMetadataOutputObjectsDelegate
  ) async throws -> QRSessionConfiguration
  public var startRunning: @Sendable (AVCaptureSession) async -> Void = { _ in }
  public var setTorch: @Sendable (AVCaptureSession, Bool) async throws -> Bool
  public var stopRunning: @Sendable (AVCaptureSession) async -> Void = { _ in }
}

public struct QRSessionConfiguration {
  public let session: AVCaptureSession
  public let hasTorch: Bool

  public init(session: AVCaptureSession, hasTorch: Bool) {
    self.session = session
    self.hasTorch = hasTorch
  }
}

public enum CameraSessionError: Error, Equatable {
  case permissionDenied
  case noBackCamera
  case cannotAddInput
  case cannotAddOutput
}
