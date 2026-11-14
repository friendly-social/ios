import Foundation
import Models
import StorageServiceLive

struct NotificationSessionStorageLive: Sendable {
  func save(_ session: NotificationSession) throws {
    let stored = StoredSession(userID: session.userID.int64, token: session.token.string)
    let data = try JSONEncoder().encode(stored)
    try keychain().save(data, for: Constants.key)
  }

  func load() throws -> NotificationSession? {
    guard let data = try keychain().load(for: Constants.key) else { return nil }
    let session = try JSONDecoder().decode(StoredSession.self, from: data)
    return NotificationSession(userID: UserId(session.userID), token: try Token(session.token))
  }

  func remove() throws {
    try keychain().remove(Constants.key)
  }
}

private extension NotificationSessionStorageLive {
  private struct StoredSession: Codable {
    let userID: Int64
    let token: String
  }

  private enum ConfigurationError: Error {
    case missingAccessGroup
  }

  private func keychain() throws -> KeychainStorageServiceLive {
    guard let group = Bundle.main.object(forInfoDictionaryKey: Constants.accessGroupKey) as? String,
          !group.isEmpty, !group.contains("$(") else { throw ConfigurationError.missingAccessGroup }
    return KeychainStorageServiceLive(accessGroup: group)
  }
}

private enum Constants {
  static let accessGroupKey = "NotificationKeychainAccessGroup"
  static let key = "notifications.session"
}
