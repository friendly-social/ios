import Foundation
import NotificationDetailsApi

struct NotificationPresentation: Sendable {
  let title: String
  let body: String
  let senderImage: NotificationSenderImage?

  init(details: NotificationDetails) {
    switch details {
    case let .friendRequest(nickname, isMutual, image):
      senderImage = image
      if isMutual {
        title = String(localized: .pushFriendRequestAcceptedTitle(nickname))
      } else {
        title = String(localized: .pushFriendRequestTitle(nickname))
      }
      body = ""
    case let .reply(nickname, text, image):
      title = String(localized: .pushReplyTitle(nickname))
      body = text
      senderImage = image
    }
  }
}
