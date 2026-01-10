import Foundation

struct Transport {
    private let baseUrl: URL
    private let session: URLSession

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        baseUrl: URL,
        session: URLSession = .shared,
    ) {
        self.baseUrl = baseUrl
        self.session = session
    }

    enum UnauthorizedError: Error {
        case ioError(Error)
        case serverError
    }

    func unauthorized<T>(
        path: String,
        method: Method,
        body: Encodable?,
        type: T.Type,
    ) async throws(UnauthorizedError) -> T where T: Decodable {
        let url = baseUrl.appending(path: path)
        var request = URLRequest(url: url)
        let httpMethod = switch method {
        case .get: "GET"
        case .post: "POST"
        }
        request.httpMethod = httpMethod
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type",
        )
        do {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw UnauthorizedError.serverError
            }
            guard response.statusCode == 200 else {
                throw UnauthorizedError.serverError
            }
            return try decoder.decode(type, from: data)
        } catch let error as UnauthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    enum AuthorizedError: Error {
        case ioError(Error)
        case serverError(String)
        case unauthorized
    }

    func authorized<T>(
        path: String,
        method: Method,
        body: Encodable?,
        type: T.Type,
        authorization: Authorization,
    ) async throws(AuthorizedError) -> T where T: Decodable {
        let url = baseUrl.appending(path: path)
        var request = URLRequest(url: url)
        let httpMethod = switch method {
        case .get: "GET"
        case .post: "POST"
        }
        request.httpMethod = httpMethod
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type",
        )
        request.setValue(
            authorization.token.string,
            forHTTPHeaderField: "X-Token",
        )
        request.setValue(
            "\(authorization.id.int64)",
            forHTTPHeaderField: "X-User-Id",
        )
        do {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await session.data(for: request)
            let string = String(decoding: data, as: UTF8.self)
            guard let response = response as? HTTPURLResponse else {
                throw AuthorizedError.serverError("\(response): \(string)")
            }
            guard response.statusCode == 200 else {
                throw AuthorizedError.serverError("\(response): \(string)")
            }
            return try decoder.decode(type, from: data)
        } catch let error as AuthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    enum UploadError: Error {
        case ioError(Error)
        case serverError
    }

    func upload<T>(
        path: String,
        data: Data,
        type: T.Type,
    ) async throws(UploadError) -> T where T: Decodable {
        let url = baseUrl.appending(path: path)
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type",
        )
        let mimeType = "application/octet-stream"
        do {
            var body = Data()
            try body.append("--\(boundary)\r\n")
            try body.append(
                "Content-Disposition: form-data; " +
                    "name=\"file\"; " +
                    "filename=\"image.jpg\"; " +
                    "size=\(data.count)\r\n",
            )
            try body.append("Content-Type: \(mimeType)\r\n\r\n")
            body.append(data)
            try body.append("\r\n")
            try body.append("--\(boundary)--\r\n")
            let (responseData, response) = try await session.upload(
                for: request,
                from: body,
            )
            guard let response = response as? HTTPURLResponse else {
                throw UploadError.serverError
            }
            guard response.statusCode == 200 else {
                throw UploadError.serverError
            }
            return try decoder.decode(type, from: responseData)
        } catch let error as UploadError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    enum Method {
        case get
        case post
    }

}

private extension Data {
    mutating func append(_ string: String) throws(AppendError) {
        guard let data = string.data(using: .utf8) else {
            throw .data
        }
        append(data)
    }

    enum AppendError: Error {
        case data
    }
}
