import DependenciesMacros
import Foundation

@DependencyClient
public struct CameraPermissionService: Sendable {
  public var status: @Sendable () -> AccessState = { .denied }
  public var request: @Sendable () async -> Bool = { false }
  public var settingsURL: @Sendable () -> URL? = { nil }
}

extension CameraPermissionService {
  public enum AccessState: Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
  }
}
