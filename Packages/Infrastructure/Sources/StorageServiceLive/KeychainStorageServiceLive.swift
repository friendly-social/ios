import Foundation
import Security

public struct KeychainStorageServiceLive: Sendable {
  private let accessGroup: String?

  public init(accessGroup: String? = nil) {
    self.accessGroup = accessGroup
  }

  public func save(_ data: Data, for key: String) throws {
    var attributes = query(for: key)
    let status = SecItemUpdate(attributes as CFDictionary, [kSecValueData: data] as CFDictionary)
    if status == errSecSuccess { return }
    guard status == errSecItemNotFound else { throw KeychainStorageError.status(status) }
    attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    attributes[kSecValueData] = data
    let addStatus = SecItemAdd(attributes as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw KeychainStorageError.status(addStatus) }
  }

  public func load(for key: String) throws -> Data? {
    var value: AnyObject?
    var attributes = query(for: key)
    attributes[kSecReturnData] = true
    let status = SecItemCopyMatching(attributes as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = value as? Data else {
      throw KeychainStorageError.status(status)
    }
    return data
  }

  func contains(_ key: String) throws -> Bool {
    let status = SecItemCopyMatching(query(for: key) as CFDictionary, nil)
    if status == errSecItemNotFound { return false }
    guard status == errSecSuccess else { throw KeychainStorageError.status(status) }
    return true
  }

  public func remove(_ key: String) throws {
    let status = SecItemDelete(query(for: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainStorageError.status(status)
    }
  }
}

private extension KeychainStorageServiceLive {
  private func query(for key: String) -> [CFString: Any] {
    var attributes: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
    if let accessGroup { attributes[kSecAttrAccessGroup] = accessGroup }
    return attributes
  }
}

enum KeychainStorageError: Error {
  case status(OSStatus)
}
