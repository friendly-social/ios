import ConcurrencyExtras
import Dependencies
import Foundation
import Models
import NotificationSessionStorage
import StorageService

struct AccountStorageServiceLive: Sendable {
  @Dependency(NotificationSessionStorage.self) private var notificationSession
  @Dependency(SecureStorageService.self) private var secureStorage
  private let sessionLock = LockIsolated(())

  func saveAuthorization(_ authorization: Authorization) throws(Error) {
    do {
      try sessionLock.withValue { _ in
        if (try? readPrivateAuthorization().token) != authorization.token {
          try? notificationSession.remove()
        }
        try savePrivateAuthorization(authorization)
      }
    } catch { throw .ioError }
  }

  func loadAuthorization() throws(Error) -> Authorization {
    do { return try sessionLock.withValue { _ in try readPrivateAuthorization() } }
    catch { throw .ioError }
  }

  func hasAuthorization() throws(Error) -> Bool {
    do {
      return try sessionLock.withValue { _ in
        try secureStorage.contains(Constants.accessHash)
      }
    } catch { throw .ioError }
  }

  func clearAuthorization() {
    sessionLock.withValue { _ in clearStoredAuthorization() }
  }

  func shareNotificationSession(_ authorization: Authorization) throws {
    try sessionLock.withValue { _ in
      guard let current = try? readPrivateAuthorization(),
            current.id == authorization.id, current.token == authorization.token else {
        throw CancellationError()
      }
      let session = NotificationSession(
        userID: authorization.id,
        token: authorization.token
      )
      guard (try? notificationSession.load()) != session else { return }
      try notificationSession.save(session: session)
    }
  }

  func getHasFriend() throws(Error) -> Bool {
    do { return try secureStorage.load(Constants.hasFriend)?.first == 1 }
    catch { throw .ioError }
  }

  func addFriend() throws(Error) {
    do { try secureStorage.save(Data([1]), Constants.hasFriend) }
    catch { throw .ioError }
  }

  func saveCommunityProfile(_ profile: CachedAccountProfile) throws(Error) {
    do {
      let data = try JSONEncoder().encode(profile)
      try secureStorage.save(data, communityProfileKey(profile.id))
    } catch { throw .ioError }
  }

  func loadCommunityProfile(accountID: Int64) throws(Error) -> CachedAccountProfile? {
    do {
      guard let data = try secureStorage.load(communityProfileKey(accountID)) else {
        return nil
      }
      let profile = try JSONDecoder().decode(CachedAccountProfile.self, from: data)
      guard profile.id == accountID else { throw Error.ioError }
      return profile
    } catch { throw .ioError }
  }

  enum Error: Swift.Error {
    case ioError
  }
}

private extension AccountStorageServiceLive {
  private func readPrivateAuthorization() throws(Error) -> Authorization {
    do {
      guard let tokenData = try secureStorage.load(Constants.token),
            let idData = try secureStorage.load(Constants.id),
            let hashData = try secureStorage.load(Constants.accessHash),
            idData.count == MemoryLayout<Int64>.size else { throw Error.ioError }
      let id = idData.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
      return Authorization(
        token: try Token(String(decoding: tokenData, as: UTF8.self)),
        id: UserId(id),
        accessHash: try UserAccessHash(String(decoding: hashData, as: UTF8.self))
      )
    } catch { throw .ioError }
  }

  private func savePrivateAuthorization(_ authorization: Authorization) throws(Error) {
    do {
      try secureStorage.save(Data(authorization.token.string.utf8), Constants.token)
      try secureStorage.save(
        withUnsafeBytes(of: authorization.id.int64) { Data($0) },
        Constants.id
      )
      try secureStorage.save(Data(authorization.accessHash.string.utf8), Constants.accessHash)
    } catch {
      clearStoredAuthorization()
      throw .ioError
    }
  }

  private func clearStoredAuthorization() {
    try? notificationSession.remove()
    if let authorization = try? readPrivateAuthorization() {
      let key = communityProfileKey(authorization.id.int64)
      try? secureStorage.remove(key)
    }
    for key in [Constants.token, Constants.id, Constants.accessHash, Constants.hasFriend] {
      try? secureStorage.remove(key)
    }
  }

  private func communityProfileKey(_ accountID: Int64) -> String {
    "community.profile.\(accountID)"
  }
}

private enum Constants {
  static let token = "authorization.token"
  static let id = "authorization.id"
  static let accessHash = "authorization.accessHash"
  static let hasFriend = "authorization.hasFriend"
}
