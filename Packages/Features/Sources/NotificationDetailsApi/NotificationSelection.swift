import Models

public struct NotificationSelection: Hashable, Sendable {
  public let id: Int64
  public let context: NotificationContext?

  public init(id: Int64, context: NotificationContext? = nil) {
    self.id = id
    self.context = context
  }
}

public struct NotificationContext: Codable, Hashable, Sendable {
  private let version: Int
  private let notificationID: Int64
  private let accountID: Int64
  private let kind: Kind
  private let targetID: Int64
  private let accessHash: String

  public init(notificationID: Int64, accountID: Int64, target: NotificationTarget) {
    version = 1
    self.notificationID = notificationID
    self.accountID = accountID
    switch target {
    case let .profile(id, accessHash):
      kind = .profile
      targetID = id.int64
      self.accessHash = accessHash.string
    case let .reply(id, accessHash):
      kind = .reply
      targetID = id
      self.accessHash = accessHash
    }
  }

  public func target(notificationID: Int64, accountID: Int64) -> NotificationTarget? {
    guard version == 1, self.notificationID == notificationID,
          self.accountID == accountID, targetID > 0, !accessHash.isEmpty else { return nil }
    switch kind {
    case .profile:
      guard let hash = try? UserAccessHash(accessHash) else { return nil }
      return .profile(id: UserId(targetID), accessHash: hash)
    case .reply: return .reply(id: targetID, accessHash: accessHash)
    }
  }
}

private extension NotificationContext {
  private enum Kind: String, Codable {
    case profile
    case reply
  }
}
