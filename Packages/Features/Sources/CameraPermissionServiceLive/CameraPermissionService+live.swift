import CameraPermissionService
import Dependencies

extension CameraPermissionService: DependencyKey {
  public static var liveValue: Self {
    let live = CameraPermissionServiceLive()
    return .init(
      status: { live.status() },
      request: { await live.request() },
      settingsURL: { live.settingsURL() }
    )
  }
}
