import AVFoundation
import DependenciesMacros

@DependencyClient
public struct QRSessionService: Sendable {
  public var makeSession: @Sendable (
    AVCaptureMetadataOutputObjectsDelegate
  ) async throws -> AVCaptureSession
  public var startRunning: @Sendable (AVCaptureSession) async -> Void = { _ in }
  public var stopRunning: @Sendable (AVCaptureSession) async -> Void = { _ in }
}

public enum CameraSessionError: Error, Equatable {
  case permissionDenied
  case noBackCamera
  case cannotAddInput
  case cannotAddOutput
}
