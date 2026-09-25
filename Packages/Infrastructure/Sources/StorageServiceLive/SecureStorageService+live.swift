import Dependencies
import StorageService

extension SecureStorageService {
  public static func live() -> Self {
    let live = KeychainStorageServiceLive()
    return .init(
      save: live.save,
      load: live.load,
      contains: live.contains,
      remove: live.remove
    )
  }
}

extension SecureStorageService: DependencyKey {
  public static var liveValue: Self { .live() }
}
