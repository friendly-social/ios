@testable import AccountStorageServiceLive
import Dependencies
import Foundation
import Models
import NotificationSessionStorage
import StorageService
import Synchronization
import Testing

struct AccountNotificationSessionTests {
  @Test func switchingAccountsCannotReshareThePreviousSession() throws {
    let storage = TestStorage()
    let accounts = storage.makeAccountStorage()
    let first = try makeAuthorization(id: 7, tokenCharacter: "a")
    let second = try makeAuthorization(id: 8, tokenCharacter: "b")
    try accounts.saveAuthorization(first)
    try accounts.shareNotificationSession(first)
    #expect(storage.sharedSession?.userID == first.id)
    try accounts.saveAuthorization(second)
    #expect(storage.sharedSession == nil)
    #expect(throws: CancellationError.self) {
      try accounts.shareNotificationSession(first)
    }
    #expect(storage.sharedSession == nil)
    try accounts.shareNotificationSession(second)
    #expect(storage.sharedSession?.userID == second.id)
    accounts.clearAuthorization()
    #expect(storage.sharedSession == nil)
  }
}

private extension AccountNotificationSessionTests {
  private func makeAuthorization(id: Int64, tokenCharacter: Character) throws -> Authorization {
    try Authorization(
      token: Token(String(repeating: String(tokenCharacter), count: Token.length)),
      id: UserId(id),
      accessHash: UserAccessHash(String(repeating: "h", count: UserAccessHash.length))
    )
  }
}

private final class TestStorage: Sendable {
  private let data = Mutex([String: Data]())
  private let session = Mutex<NotificationSession?>(nil)

  var sharedSession: NotificationSession? {
    session.withLock { $0 }
  }
}

private extension TestStorage {
  func makeAccountStorage() -> AccountStorageServiceLive {
    let privateStorage = SecureStorageService(
      save: { value, key in self.data.withLock { $0[key] = value } },
      load: { key in self.data.withLock { $0[key] } },
      contains: { key in self.data.withLock { $0[key] != nil } },
      remove: { key in self.data.withLock { $0[key] = nil } }
    )
    let sharedStorage = NotificationSessionStorage(
      save: { value in self.session.withLock { $0 = value } },
      load: { self.sharedSession },
      remove: { self.session.withLock { $0 = nil } }
    )
    return withDependencies {
      $0[NotificationSessionStorage.self] = sharedStorage
      $0[SecureStorageService.self] = privateStorage
    } operation: {
      AccountStorageServiceLive()
    }
  }
}
