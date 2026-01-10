import Security
import Foundation

class Storage {
    func saveAuthorization(_ authorization: Authorization) throws(Error) {
        do {
            try saveToken(authorization.token)
            try saveId(authorization.id)
            try saveAccessHash(authorization.accessHash)
        } catch {
            clearAuthorization()
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

    func clearAuthorization() {
        try? clearToken()
        try? clearId()
        try? clearAccessHash()
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

    func loadAuthorization() throws(Error) -> Authorization {
        let token = try loadToken()
        let id = try loadId()
        let accessHash = try loadAccessHash()
        return Authorization(
            token: token,
            id: id,
            accessHash: accessHash,
        )
    }

    private func loadToken() throws(Error) -> Token {
        var data: AnyObject?
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.token",
            kSecReturnData: true,
        ] as CFDictionary
        let status = SecItemCopyMatching(query, &data)
        guard status == errSecSuccess else {
            throw .ioError
        }
        guard let data = data as? Data else {
            throw .ioError
        }
        let string = String(decoding: data, as: UTF8.self)
        return try! Token(string)
    }

    private func loadId() throws(Error) -> UserId {
        var data: AnyObject?
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.id",
            kSecReturnData: true,
        ] as CFDictionary
        let status = SecItemCopyMatching(query, &data)
        guard status == errSecSuccess else {
            throw .ioError
        }
        guard let data = data as? Data else {
            throw .ioError
        }
        let int64 = data.withUnsafeBytes { bytes in
            bytes.load(as: Int64.self)
        }
        return UserId(int64)
    }

    private func loadAccessHash() throws(Error) -> UserAccessHash {
        var data: AnyObject?
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "authorization.accessHash",
            kSecReturnData: true,
        ] as CFDictionary
        let status = SecItemCopyMatching(query, &data)
        guard status == errSecSuccess else {
            throw .ioError
        }
        guard let data = data as? Data else {
            throw .ioError
        }
        let string = String(decoding: data, as: UTF8.self)
        return try! UserAccessHash(string)
    }

    enum Error: Swift.Error {
        case ioError
    }

    static let shared: Storage = Storage()
}
