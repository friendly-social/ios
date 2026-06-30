import Foundation

final class EmailAuthWorker {
    private let networkClient: NetworkClient

    init(networkClient: NetworkClient = .meetacy) {
        self.networkClient = networkClient
    }

    func requestBindingCode(
        authorization: Authorization,
        email: String,
    ) async throws {
        do {
            try await networkClient.emailLink(
                authorization: authorization,
                email: email,
            )
            try Task.checkCancellation()
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    func confirmBinding(
        authorization: Authorization,
        code: Int,
    ) async throws {
        do {
            try await networkClient.emailConfirm(
                authorization: authorization,
                code: code,
            )
            try Task.checkCancellation()
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    func requestLoginCode(email: String) async throws {
        do {
            try await networkClient.authEmail(email: email)
            try Task.checkCancellation()
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    func login(
        email: String,
        code: Int,
    ) async throws -> Authorization {
        do {
            let authorization = try await networkClient.authLogin(
                email: email,
                code: code,
            )
            try Task.checkCancellation()
            return authorization
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }
}
