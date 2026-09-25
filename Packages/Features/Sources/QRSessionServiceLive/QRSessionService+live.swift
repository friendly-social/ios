import CameraPermissionService
import Dependencies
import QRSessionService

extension QRSessionService: DependencyKey {
  public static var liveValue: Self {
    @Dependency(CameraPermissionService.self) var permission
    let live = QRSessionServiceLive(permission: permission)
    return .init(
      makeSession: { delegate in
        try await live.makeSession(delegate: delegate)
      },
      startRunning: { session in await live.startRunning(session) },
      stopRunning: { session in await live.stopRunning(session) }
    )
  }
}
