import Foundation
import SwiftUI

// todo: move to a separate swift module
class NetworkClient {
    private let transport: Transport
    let baseUrl: URL
    let landingUrl: URL

    init(
        baseUrl: URL,
        landingUrl: URL,
        session: URLSession = .shared,
    ) {
        self.baseUrl = baseUrl
        self.landingUrl = landingUrl
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
        socialLink: SocialLink?,
    ) async throws(AuthGenerateError) -> Authorization {
        let body = AuthGenerateRequestBody(
            nickname: nickname.string,
            description: description.string,
            interests: interests.map(\.string),
            avatar: avatar?.serializable(),
            socialLink: socialLink?.string,
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
        @EncodeNil var socialLink: String?
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

    enum FeedQueueError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func feedQueue(
        authorization: Authorization,
    ) async throws(FeedQueueError) -> FeedQueue {
        do {
            let response = try await transport.authorized(
                path: "feed/queue",
                method: .get,
                body: nil,
                type: FeedQueueSerializable.self,
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

    private struct FriendsGenerateResponseBody: Decodable {
        let token: String
    }

    enum FriendsAddError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func friendsAdd(
        authorization: Authorization,
        token: FriendToken,
        id: UserId,
    ) async throws(FriendsAddError) {
        do {
            let body = FriendsAddRequestBody(
                token: token.string,
                userId: id.int64,
            )
            let _ = try await transport.authorized(
                path: "friends/add",
                method: .post,
                body: body,
                type: FriendsAddResponseBody.self,
                authorization: authorization,
            )
        } catch {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            case .unauthorized: throw .unauthorized
            }
        }
    }

    private struct FriendsAddRequestBody: Encodable {
        let token: String
        let userId: Int64
    }

    private struct FriendsAddResponseBody: Decodable {}

    enum FriendsDeclineError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func friendsDecline(
        authorization: Authorization,
        id: UserId,
        accessHash: UserAccessHash,
    ) async throws(FriendsDeclineError) {
        do {
            let body = FriendsDeclineRequestBody(
                userId: id.int64,
                userAccessHash: accessHash.string,
            )
            let _ = try await transport.authorized(
                path: "friends/decline",
                method: .post,
                body: body,
                type: FriendsDeclineResponseBody.self,
                authorization: authorization,
            )
        } catch {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            case .unauthorized: throw .unauthorized
            }
        }
    }

    private struct FriendsDeclineRequestBody: Encodable {
        let userId: Int64
        let userAccessHash: String
    }

    private struct FriendsDeclineResponseBody: Decodable {}


    enum FriendsRequestError: Error {
        case ioError(Error)
        case serverError
        case unauthorized
    }

    func friendsRequest(
        authorization: Authorization,
        id: UserId,
        accessHash: UserAccessHash,
    ) async throws(FriendsRequestError) {
        do {
            let body = FriendsRequestRequestBody(
                userId: id.int64,
                userAccessHash: accessHash.string,
            )
            let _ = try await transport.authorized(
                path: "friends/request",
                method: .post,
                body: body,
                type: FriendsRequestResponseBody.self,
                authorization: authorization,
            )
        } catch {
            switch error {
            case .ioError(let error): throw .ioError(error)
            case .serverError: throw .serverError
            case .unauthorized: throw .unauthorized
            }
        }
    }

    private struct FriendsRequestRequestBody: Encodable {
        let userId: Int64
        let userAccessHash: String
    }

    private struct FriendsRequestResponseBody: Decodable {}

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
        landingUrl: URL(
            string: "https://friendly-social.github.io/landing/#/",
        )!,
    )
}

