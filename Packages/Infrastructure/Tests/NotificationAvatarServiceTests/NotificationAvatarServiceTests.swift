import CoreGraphics
import Dependencies
import Foundation
import ImageIO
import NotificationAvatarService
@testable import NotificationAvatarServiceLive
import Testing
import UniformTypeIdentifiers

struct NotificationAvatarServiceTests {
  @Test func makesBoundedThumbnail() async throws {
    let data = try await service().load(url: URL(string: "https://example.com/avatar")!)
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 192)
    #expect(image.height == 192)
  }

  @Test(
    arguments: [
      "server-error",
      "network-error",
      "invalid-image",
    ]
  )
  func rejectsUnavailableAvatar(path: String) async {
    await #expect(throws: NotificationAvatarError.unavailable) {
      try await service().load(url: URL(string: "https://example.com/\(path)")!)
    }
  }

  @Test(arguments: ["oversized", "streamed-oversized"])
  func rejectsOversizedDecodableImages(path: String) async throws {
    let data = AvatarURLProtocol.responseData(path: "/\(path)")
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 300)
    await #expect(throws: NotificationAvatarError.unavailable) {
      try await service().load(url: URL(string: "https://example.com/\(path)")!)
    }
  }

  @Test(arguments: ["http://example.com/avatar", "file:///tmp/avatar"])
  func rejectsNonHTTPSURLs(url: String) async {
    await #expect(throws: NotificationAvatarError.unavailable) {
      try await service().load(url: URL(string: url)!)
    }
  }
}

private extension NotificationAvatarServiceTests {
  private func service() -> NotificationAvatarServiceLive {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [AvatarURLProtocol.self]
    return withDependencies {
      $0[NotificationAvatarSessionKey.self] = URLSession(configuration: configuration)
    } operation: {
      NotificationAvatarServiceLive()
    }
  }
}

// Responses depend only on the request path and immutable fixture data.
private final class AvatarURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    guard url.path != "/network-error" else {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    let data = Self.responseData(path: url.path)
    let status = url.path == "/server-error" ? 500 : 200
    let response = HTTPURLResponse(
      url: url,
      statusCode: status,
      httpVersion: nil,
      headerFields: url.path == "/streamed-oversized" ? [:] : ["Content-Length": String(data.count)]
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

private extension AvatarURLProtocol {
  private static let imageData = makeImageData()

  static func responseData(path: String) -> Data {
    switch path {
    case "/invalid-image": return Data("invalid".utf8)
    case "/oversized", "/streamed-oversized":
      var data = imageData
      data.append(Data(repeating: 0, count: 1024 * 1024 + 1 - data.count))
      return data
    default: return imageData
    }
  }

  private static func makeImageData() -> Data {
    let context = CGContext(
      data: nil,
      width: 300,
      height: 300,
      bitsPerComponent: 8,
      bytesPerRow: 1200,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(gray: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    )!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    return data as Data
  }
}
