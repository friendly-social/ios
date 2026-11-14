import CommunityProfileService
import Foundation
import NotificationDetailsApi
import NotificationOpeningService

extension AppViewModel {
  enum Destination: Hashable, Identifiable {
    case notification(Notification)

    var id: UUID {
      switch self {
      case let .notification(notification): notification.id
      }
    }
  }

  struct Notification: Hashable {
    let id = UUID()
    let selection: NotificationSelection
    var session: CommunitySession?
    var content: OpenedNotification?
    var isLoading = false
    var failed = false

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
  }

  enum Screen: Hashable {
    case empty
    case signUp
    case main
    case qrAddFriend
  }

  enum MainRoute: Hashable {
    case feed
    case community
    case notification(NotificationSelection)
  }

  func showNotification(_ selection: NotificationSelection) {
    destination = .notification(.init(selection: selection))
  }

  func openNotification(_ selection: NotificationSelection?) {
    guard let selection, selection.id > 0 else { return }
    mainRoute = .notification(selection)
  }
}
