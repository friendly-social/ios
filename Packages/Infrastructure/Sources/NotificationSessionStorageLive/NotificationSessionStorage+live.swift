import Dependencies
import NotificationSessionStorage

private extension NotificationSessionStorage {
  static func live() -> Self {
    let storage = NotificationSessionStorageLive()
    return Self(save: storage.save, load: storage.load, remove: storage.remove)
  }
}

extension NotificationSessionStorage: DependencyKey {
  public static let liveValue: Self = .live()
}
