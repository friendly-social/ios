import Foundation
import SwiftUI

// todo: move to a separate swift module
class NetworkClient {
    private let transport: Transport

    init(baseUrl: URL, session: URLSession = .shared) {
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

    static let meetacy = NetworkClient(
        baseUrl: URL(string: "https://meetacy.app/friendly")!,
    )
}

