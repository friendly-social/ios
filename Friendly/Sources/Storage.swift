import Security
import Foundation

class Storage {
    func saveAuthorization(_ authorization: Authorization) throws(Error) {
        do {
            try saveToken(authorization.token)
            try saveId(authorization.id)
            try saveAccessHash(authorization.accessHash)
        } catch {
            try clearAuthorization()
            throw error
        }
    }

    private func saveToken(_ token: Token) throws(Error) {
        guard let data = token.string.data(using: .utf8) else {
            throw .ioError
        }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.token",
            kSecValueData: data,
        ] as CFDictionary
        let status = SecItemAdd(query, nil)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    private func saveId(_ id: UserId) throws(Error) {
        let data = withUnsafeBytes(of: id.int64) { Data($0) }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.id",
            kSecValueData: data,
        ] as CFDictionary
        let status = SecItemAdd(query, nil)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    private func saveAccessHash(_ accessHash: UserAccessHash) throws(Error) {
        guard let data = accessHash.string.data(using: .utf8) else {
            throw .ioError
        }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.accessHash",
            kSecValueData: data,
        ] as CFDictionary
        let status = SecItemAdd(query, nil)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    func clearAuthorization() throws(Error) {
        try clearToken()
        try clearId()
        try clearAccessHash()
    }

    private func clearToken() throws(Error) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.token",
        ] as CFDictionary
        let status = SecItemDelete(query)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    private func clearId() throws(Error) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.id",
        ] as CFDictionary
        let status = SecItemDelete(query)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    private func clearAccessHash() throws(Error) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.accessHash",
        ] as CFDictionary
        let status = SecItemDelete(query)
        guard status == errSecSuccess else {
            throw .ioError
        }
    }

    func hasAuthorization() throws(Error) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.accessHash",
        ] as CFDictionary
        let status = SecItemCopyMatching(query, nil)
        if status == errSecItemNotFound { return false }
        if status == errSecSuccess { return true }
        throw .ioError
    }

    func loadAuthorization() -> Authorization? {
        fatalError("test")
    }

    enum Error : Swift.Error {
        case ioError
    }

    static let shared: Storage = Storage()
}
