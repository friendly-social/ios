import Foundation
import Security
import StorageService

struct KeychainStorageServiceLive: Sendable {
  func save(_ data: Data, for key: String) throws {
    let query = query(for: key)
    let status = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
    if status == errSecSuccess { return }
    guard status == errSecItemNotFound else { throw KeychainStorageError.status(status) }
    let add = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: key,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData: data,
    ] as CFDictionary
    let addStatus = SecItemAdd(add, nil)
    guard addStatus == errSecSuccess else { throw KeychainStorageError.status(addStatus) }
  }

  func load(for key: String) throws -> Data? {
    var value: AnyObject?
    let query = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: key,
      kSecReturnData: true,
    ] as CFDictionary
    let status = SecItemCopyMatching(query, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = value as? Data else {
      throw KeychainStorageError.status(status)
    }
    return data
  }

  func contains(_ key: String) throws -> Bool {
    let status = SecItemCopyMatching(query(for: key), nil)
    if status == errSecItemNotFound { return false }
    guard status == errSecSuccess else { throw KeychainStorageError.status(status) }
    return true
  }

  func remove(_ key: String) throws {
    let status = SecItemDelete(query(for: key))
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainStorageError.status(status)
    }
  }

  private func query(for key: String) -> CFDictionary {
    [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary
  }
}

enum KeychainStorageError: Error {
  case status(OSStatus)
}
