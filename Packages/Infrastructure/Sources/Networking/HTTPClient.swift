import Foundation

public struct HTTPClient: Sendable {
  public enum Method: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
  }

  public struct Request: Sendable {
    public struct Options: Sendable {
      public var urlPath: String
      public var queryItems: [URLQueryItem]
      public var headers: [String: String]

      public init(
        urlPath: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:]
      ) {
        self.urlPath = urlPath
        self.queryItems = queryItems
        self.headers = headers
      }
    }

    public var path: String
    public var method: Method
    public var query: [URLQueryItem]
    public var headers: [String: String]
    public var body: Data?
    public var cachePolicy: URLRequest.CachePolicy
    public var timeout: TimeInterval

    public init(
      path: String,
      method: Method = .get,
      query: [URLQueryItem] = [],
      headers: [String: String] = [:],
      body: Data? = nil,
      cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
      timeout: TimeInterval = 30
    ) {
      self.path = path
      self.method = method
      self.query = query
      self.headers = headers
      self.body = body
      self.cachePolicy = cachePolicy
      self.timeout = timeout
    }

    public mutating func encode<Body: Encodable>(_ body: Body, using encoder: JSONEncoder = JSONEncoder()) throws {
      self.body = try encoder.encode(body)
      headers["Content-Type"] = "application/json"
    }

    public static func get(options: Options) -> Self {
      .init(path: options.urlPath, query: options.queryItems, headers: options.headers)
    }

    public static func post<Body: Encodable>(
      options: Options,
      body: Body,
      encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
      var request = Self(path: options.urlPath, method: .post, query: options.queryItems, headers: options.headers)
      try request.encode(body, using: encoder)
      return request
    }

    public static func post(options: Options) -> Self {
      .init(path: options.urlPath, method: .post, query: options.queryItems, headers: options.headers)
    }

    public static func patch<Body: Encodable>(
      options: Options,
      body: Body,
      encoder: JSONEncoder = JSONEncoder()
    ) throws -> Self {
      var request = Self(path: options.urlPath, method: .patch, query: options.queryItems, headers: options.headers)
      try request.encode(body, using: encoder)
      return request
    }
  }

  public let baseURL: URL
  private let transport: HTTPTransport

  public init(baseURL: URL, transport: HTTPTransport) {
    self.baseURL = baseURL
    self.transport = transport
  }

  public func send(_ request: Request) async throws -> HTTPResponse {
    var url = baseURL.appending(path: request.path)
    if !request.query.isEmpty {
      url.append(queryItems: request.query)
    }
    var urlRequest = URLRequest(url: url, cachePolicy: request.cachePolicy, timeoutInterval: request.timeout)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.httpBody = request.body
    for (name, value) in request.headers {
      urlRequest.setValue(value, forHTTPHeaderField: name)
    }
    return try await transport.data(urlRequest)
  }

  public func decode<Response: Decodable>(
    _ type: Response.Type,
    from response: HTTPResponse,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> Response {
    try decoder.decode(type, from: response.data)
  }

  public func decode<Response: Decodable>(
    _ response: HTTPResponse,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> Response {
    try decoder.decode(Response.self, from: response.data)
  }

  public func send<Response: Decodable>(
    _ request: Request,
    decoding type: Response.Type,
    acceptableStatus: Range<Int> = 200..<300,
    using decoder: JSONDecoder = JSONDecoder()
  ) async throws -> Response {
    let response = try await send(request)
    guard acceptableStatus.contains(response.statusCode) else {
      throw HTTPStatusError(response: response)
    }
    return try decode(type, from: response, using: decoder)
  }

  public func push<Response: Decodable>(
    request: Request,
    using decoder: JSONDecoder = JSONDecoder()
  ) async throws -> Response {
    try await send(request, decoding: Response.self, using: decoder)
  }

  public func upload(_ request: Request, data: Data) async throws -> HTTPResponse {
    var url = baseURL.appending(path: request.path)
    if !request.query.isEmpty {
      url.append(queryItems: request.query)
    }
    var urlRequest = URLRequest(url: url, cachePolicy: request.cachePolicy, timeoutInterval: request.timeout)
    urlRequest.httpMethod = request.method.rawValue
    for (name, value) in request.headers {
      urlRequest.setValue(value, forHTTPHeaderField: name)
    }
    return try await transport.upload(urlRequest, data)
  }
}

public struct HTTPStatusError: Error, Sendable {
  public let response: HTTPResponse

  public init(response: HTTPResponse) {
    self.response = response
  }
}
