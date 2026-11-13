import Dependencies
import Foundation
import ImageIO
import NotificationAvatarService
import UniformTypeIdentifiers

struct NotificationAvatarServiceLive: Sendable {
  @Dependency(NotificationAvatarSessionKey.self) private var session

  func load(url: URL) async throws -> Data {
    guard url.scheme?.lowercased() == "https", url.host != nil else {
      throw NotificationAvatarError.unavailable
    }
    do {
      return try await downloadThumbnail(url: url)
    } catch {
      try Task.checkCancellation()
      throw NotificationAvatarError.unavailable
    }
  }
}

private extension NotificationAvatarServiceLive {
  private func downloadThumbnail(url: URL) async throws -> Data {
    let request = URLRequest(url: url, timeoutInterval: Constants.timeout)
    let (bytes, response) = try await session.bytes(for: request)
    defer { bytes.task.cancel() }
    guard let response = response as? HTTPURLResponse,
          response.statusCode == 200,
          response.expectedContentLength <= Constants.maximumBytes else {
      throw NotificationAvatarError.unavailable
    }
    let data = try await read(bytes)
    return try thumbnail(from: data)
  }

  private func read(_ bytes: URLSession.AsyncBytes) async throws -> Data {
    var data = Data()
    for try await byte in bytes {
      guard data.count < Constants.maximumBytes else { throw NotificationAvatarError.unavailable }
      data.append(byte)
    }
    try Task.checkCancellation()
    return data
  }

  private func thumbnail(from data: Data) throws -> Data {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: Constants.maximumPixels,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw NotificationAvatarError.unavailable
    }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      output,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else {
      throw NotificationAvatarError.unavailable
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NotificationAvatarError.unavailable }
    return output as Data
  }
}

enum NotificationAvatarSessionKey: DependencyKey {
  static var liveValue: URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = Constants.timeout
    configuration.timeoutIntervalForResource = Constants.timeout
    return URLSession(configuration: configuration)
  }
}

private enum Constants {
  static let maximumBytes = 1024 * 1024
  static let maximumPixels = 192
  static let timeout: TimeInterval = 4
}
