import Dependencies
import Foundation
import Intents
import NotificationAvatarService
import NotificationDetailsApi
import NotificationSessionStorage
import UserNotifications

struct NotificationEnrichmentServiceLive: Sendable {
  @Dependency(NotificationAvatarService.self) private var avatars
  @Dependency(NotificationDetailsApi.self) private var notificationDetails
  @Dependency(NotificationSessionStorage.self) private var sessions

  func content(request: UNNotificationRequest) async -> UNNotificationContent? {
    guard let rawID = request.content.userInfo["id"] as? String,
          let id = Int64(rawID), id > 0,
          let session = try? sessions.load(),
          let details = try? await notificationDetails.content(id: id, session: session) else {
      return nil
    }
    guard !Task.isCancelled, (try? sessions.load()) == session,
          let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      return nil
    }
    let presentation = NotificationPresentation(details: details.details)
    content.title = presentation.title
    content.body = presentation.body
    if let target = details.target {
      let context = NotificationContext(
        notificationID: id,
        accountID: session.userID.int64,
        target: target
      )
      store(context, in: content)
    }
    let enriched = await communicationContent(from: content, presentation: presentation)
    guard !Task.isCancelled, (try? sessions.load()) == session else { return nil }
    return enriched
  }
}

private extension NotificationEnrichmentServiceLive {
  private func store(_ context: NotificationContext, in content: UNMutableNotificationContent) {
    guard let data = try? JSONEncoder().encode(context) else { return }
    content.userInfo["friendly.context"] = String(decoding: data, as: UTF8.self)
  }

  private func communicationContent(
    from original: UNNotificationContent,
    presentation: NotificationPresentation
  ) async -> UNNotificationContent {
    guard let senderImage = presentation.senderImage else { return original }
    do {
      let data = try await avatars.load(url: senderImage.url)
      try Task.checkCancellation()
      let intent = intent(senderID: senderImage.senderID, data: data, title: presentation.title)
      let interaction = INInteraction(intent: intent, response: nil)
      interaction.direction = .incoming
      try await interaction.donate()
      try Task.checkCancellation()
      return try original.updating(from: intent)
    } catch { return original }
  }

  private func intent(senderID: Int64, data: Data, title: String) -> INSendMessageIntent {
    let image = INImage(imageData: data)
    let intent = INSendMessageIntent(
      recipients: nil,
      outgoingMessageType: .outgoingMessageText,
      content: nil,
      speakableGroupName: nil,
      conversationIdentifier: nil,
      serviceName: nil,
      sender: person(senderID: String(senderID), title: title, image: image),
      attachments: nil
    )
    intent.setImage(image, forParameterNamed: \.sender)
    return intent
  }

  private func person(senderID: String, title: String, image: INImage) -> INPerson {
    INPerson(
      personHandle: INPersonHandle(value: senderID, type: .unknown),
      nameComponents: nil,
      displayName: title,
      image: image,
      contactIdentifier: nil,
      customIdentifier: senderID
    )
  }
}
