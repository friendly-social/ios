import Synchronization
import UserNotifications

final class NotificationDeliveryContext: Sendable {
  private let state: Mutex<State?>

  init(
    original: UNNotificationContent,
    contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    state = Mutex(State(original: original, contentHandler: contentHandler))
  }

  func start(_ load: @escaping @Sendable () async -> UNNotificationContent?) {
    state.withLock { state in
      guard state != nil else { return }
      state?.task = Task { [weak self] in
        let content = await load()
        self?.finish(with: content)
      }
    }
  }

  func finish(with content: UNNotificationContent? = nil) {
    let completed = state.withLock { current in
      defer { current = nil }
      return current
    }
    guard let completed else { return }
    completed.task?.cancel()
    completed.contentHandler(content ?? completed.original)
  }
}

private extension NotificationDeliveryContext {
  private struct State {
    let original: UNNotificationContent
    let contentHandler: (UNNotificationContent) -> Void
    var task: Task<Void, Never>?
  }
}
