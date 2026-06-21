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
        case serverError(statusCode: Int, body: String)
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
        case .patch: "PATCH"
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
                throw UnauthorizedError.serverError(
                    statusCode: 0,
                    body: String(decoding: data, as: UTF8.self),
                )
            }
            guard response.statusCode == 200 else {
                throw UnauthorizedError.serverError(
                    statusCode: response.statusCode,
                    body: String(decoding: data, as: UTF8.self),
                )
            }
            return try decoder.decode(type, from: data)
        } catch let error as UnauthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    func unauthorizedVoid(
        path: String,
        method: Method,
        body: Encodable?,
        headers: [String: String] = [:],
    ) async throws(UnauthorizedError) {
        let url = baseUrl.appending(path: path)
        var request = URLRequest(url: url)
        let httpMethod = switch method {
        case .get: "GET"
        case .post: "POST"
        case .patch: "PATCH"
        }
        request.httpMethod = httpMethod
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type",
        )
        apply(headers: headers, to: &request)
        do {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw UnauthorizedError.serverError(
                    statusCode: 0,
                    body: String(decoding: data, as: UTF8.self),
                )
            }
            guard response.statusCode == 200 else {
                throw UnauthorizedError.serverError(
                    statusCode: response.statusCode,
                    body: String(decoding: data, as: UTF8.self),
                )
            }
            return
        } catch let error as UnauthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    enum AuthorizedError: Error {
        case ioError(Error)
        case serverError(statusCode: Int, body: String)
        case unauthorized
    }

    func authorized<T>(
        path: String,
        method: Method,
        body: Encodable?,
        type: T.Type,
        authorization: Authorization
    ) async throws(AuthorizedError) -> T where T: Decodable {
        var request = createRequestAuthorized(
            path: path,
            method: method,
            authorization: authorization
        )
        do {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await session.data(for: request)
            let string = String(decoding: data, as: UTF8.self)
            guard let response = response as? HTTPURLResponse else {
                throw AuthorizedError.serverError(statusCode: 0, body: string)
            }
            if response.statusCode == 401 {
                throw AuthorizedError.unauthorized
            }
            guard response.statusCode == 200 else {
                throw AuthorizedError.serverError(
                    statusCode: response.statusCode,
                    body: string,
                )
            }
            return try decoder.decode(type, from: data)
        } catch let error as AuthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    func authorizedVoid(
        path: String,
        method: Method,
        body: Encodable?,
        authorization: Authorization,
        headers: [String: String] = [:],
    ) async throws(AuthorizedError) {
        var request = createRequestAuthorized(
            path: path,
            method: method,
            authorization: authorization
        )
        apply(headers: headers, to: &request)
        do {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            }
            let (data, response) = try await session.data(for: request)
            let string = String(decoding: data, as: UTF8.self)

            guard let response = response as? HTTPURLResponse else {
                throw AuthorizedError.serverError(statusCode: 0, body: string)
            }
            if response.statusCode == 401 {
                throw AuthorizedError.unauthorized
            }
            guard response.statusCode == 200 else {
                throw AuthorizedError.serverError(
                    statusCode: response.statusCode,
                    body: string,
                )
            }
            return
        } catch let error as AuthorizedError {
            throw error
        } catch {
            throw .ioError(error)
        }
    }

    private func createRequestAuthorized(
        path: String,
        method: Method,
        authorization: Authorization
    )  -> URLRequest {
        let url = baseUrl.appending(path: path)
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
        )
        let httpMethod = switch method {
        case .get: "GET"
        case .post: "POST"
        case .patch: "PATCH"
        }
        request.httpMethod = httpMethod
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type",
        )
        request.setValue(
            "no-cache",
            forHTTPHeaderField: "Cache-Control",
        )
        request.setValue(
            authorization.token.string,
            forHTTPHeaderField: "X-Token",
        )
        request.setValue(
            "\(authorization.id.int64)",
            forHTTPHeaderField: "X-User-Id",
        )
        return request
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
        case patch
    }

    private func apply(
        headers: [String: String],
        to request: inout URLRequest,
    ) {
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
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
