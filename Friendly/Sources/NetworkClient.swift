import Foundation
import SwiftUI

// todo: move to a separate swift module
class NetworkClient {
    private let transport: Transport
    private let baseUrl: URL

    init(baseUrl: URL, session: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.transport = Transport(baseUrl: baseUrl, session: session)
    }

    enum AuthGenerateError: Error {
        case ioError(Error)
        case serverError
    }

    func authGenerate(
        nickname: Nickname,
        description: UserDescription,
        interests: [Interest],
        avatar: FileDescriptor?,
    ) async throws(AuthGenerateError) -> Authorization {
        let body = AuthGenerateRequestBody(
            nickname: nickname.string,
            description: description.string,
            interests: interests.map(\.string),
            avatar: avatar?.serializable(),
        )
        do {
            let response = try await transport.unauthorized(
                path: "auth/generate",
                method: .post,
                body: body,
                type: AuthGenerateResponseBody.self,
            )
            return Authorization(
                token: try Token(response.token),
                id: UserId(response.id),
                accessHash: try UserAccessHash(response.accessHash),
            )
        } catch let error as Transport.UnauthorizedError {
            switch error {
                case .ioError(let error): throw .ioError(error)
                case .serverError: throw .serverError
            }
        } catch {
            throw .serverError
        }
    }

    private struct AuthGenerateRequestBody: Encodable {
        let nickname: String
        let description: String
        let interests: [String]
        @EncodeNil var avatar: FileDescriptorSerializable?
    }

    private struct AuthGenerateResponseBody: Decodable {
        let token: String
        let id: Int64
        let accessHash: String
    }

    enum UserDetailsError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func usersDetails(
        authorization: Authorization,
        id: UserId,
        accessHash: UserAccessHash,
    ) async throws(UserDetailsError) -> UserDetails {
        let path = "users/details/\(id.int64)/\(accessHash.string)"
        do {
            let response = try await transport.authorized(
                path: path,
                method: .get,
                body: nil,
                type: UserDetailsSerializable.self,
                authorization: authorization,
            )
            return try response.typed()
        } catch let error as Transport.AuthorizedError {
            switch error {
                case .ioError(let error): throw .ioError(error)
                case .serverError: throw .serverError
                case .unauthorized: throw .unauthorized
            }
        } catch {
            throw .serverError
        }
    }

    enum NetworkDetailsError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func networkDetails(
        authorization: Authorization,
    ) async throws(NetworkDetailsError) -> NetworkDetails {
        do {
            let response = try await transport.authorized(
                path: "network/details",
                method: .get,
                body: nil,
                type: NetworkDetailsSerializable.self,
                authorization: authorization,
            )
            return try response.typed()
        } catch let error as Transport.AuthorizedError {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            case .unauthorized: throw .unauthorized
            }
        } catch {
            throw .serverError
        }
    }

    enum FriendsGenerateError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func friendsGenerate(
        authorization: Authorization,
    ) async throws(FriendsGenerateError) -> FriendToken {
        do {
            let response = try await transport.authorized(
                path: "friends/generate",
                method: .post,
                body: nil,
                type: FriendsGenerateResponseBody.self,
                authorization: authorization,
            )
            return try FriendToken(response.token)
        } catch let error as Transport.AuthorizedError {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            case .unauthorized: throw .unauthorized
            }
        } catch {
            throw .serverError
        }
    }

    private struct FriendsGenerateResponseBody : Decodable {
        let token: String
    }

    enum FilesUploadError: Error {
        case ioError(Error)
        case serverError
    }

    func filesUpload(
        data: Data,
    ) async throws(FilesUploadError) -> FileDescriptor {
        let responseBody: FileDescriptorSerializable
        do {
            responseBody = try await transport.upload(
                path: "files/upload",
                data: data,
                type: FileDescriptorSerializable.self,
            )
        } catch {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            }
        }
        do {
            return try responseBody.typed()
        } catch {
            throw .serverError
        }
    }

    func filesDownloadUrl(for descriptor: FileDescriptor) -> URL {
        let id = descriptor.id.int64
        let accessHash = descriptor.accessHash.string
        return baseUrl.appending(
            path: "files/download/\(id)/\(accessHash)",
        )
    }

    static let meetacy = NetworkClient(
        baseUrl: URL(string: "https://meetacy.app/friendly")!,
    )
}

