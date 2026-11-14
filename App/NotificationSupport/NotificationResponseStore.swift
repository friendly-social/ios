import Foundation
import NotificationDetailsApi
import Observation

@MainActor @Observable
final class NotificationResponseStore {
  private(set) var selection: NotificationSelection?

  nonisolated init() {}

  nonisolated func receive(
    _ selection: NotificationSelection?,
    completion: @escaping @Sendable () -> Void
  ) {
    DispatchQueue.main.async {
      if let selection { self.selection = selection }
      completion()
    }
  }

  func consume() -> NotificationSelection? {
    defer { selection = nil }
    return selection
  }
}
