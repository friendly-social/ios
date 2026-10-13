import CommunityEditorFeature
import CommunityProfileService
import CryptoKit
import Foundation
import ImageIO
import UIKit

actor EditorPhotoStore {
  private let directory: URL
  private var uploads: [URL: Task<URL, Error>] = [:]

  init(directory: URL) { self.directory = directory }

  func restore(_ id: UUID, fallback: Data?, session: CommunitySession) throws -> EditorPhotoContent {
    let location = url(id, session: session)
    if let record = try read(location) {
      if let url = record.uploadedURL { return .init(preview: Data(), uploadedURL: url) }
      guard let data = record.preview else { throw EditorPhotoError.missingOriginal }
      return .init(preview: data)
    }
    guard let fallback else { throw EditorPhotoError.missingOriginal }
    let data = try jpeg(fallback)
    let record = Record(preview: data, uploadedURL: nil)
    try write(record, at: location)
    return .init(preview: data)
  }

  func upload(
    _ id: UUID, session: CommunitySession,
    operation: @escaping @Sendable (Data) async throws -> URL
  ) async throws -> URL {
    let location = url(id, session: session)
    if let task = uploads[location] { return try await task.value }
    guard let record = try read(location) else { throw EditorPhotoError.missingOriginal }
    if let url = record.uploadedURL { return url }
    guard let data = record.preview else { throw EditorPhotoError.missingOriginal }
    let task = Task { try await completeUpload(data, at: location, operation: operation) }
    uploads[location] = task
    defer { uploads[location] = nil }
    return try await task.value
  }
}

private extension EditorPhotoStore {
  private struct Record: Codable {
    let preview: Data?
    var uploadedURL: URL?
  }

  private func jpeg(_ data: Data) throws -> Data {
    guard data.count <= Constants.maximumInputBytes,
          let source = CGImageSourceCreateWithData(data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary),
          let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
      throw EditorPhotoError.invalidImage
    }
    guard let result = UIImage(cgImage: bitmap).jpegData(compressionQuality: Constants.jpegQuality) else {
      throw EditorPhotoError.invalidImage
    }
    return result
  }

  private var thumbnailOptions: CFDictionary {
    [kCGImageSourceCreateThumbnailFromImageAlways: true,
     kCGImageSourceCreateThumbnailWithTransform: true,
     kCGImageSourceShouldCacheImmediately: true,
     kCGImageSourceThumbnailMaxPixelSize: Constants.maximumUploadPixels] as CFDictionary
  }

  private func completeUpload(
    _ data: Data, at location: URL, operation: @Sendable (Data) async throws -> URL
  ) async throws -> URL {
    let uploaded = try await operation(data)
    // Every waiter receives the URL only after it is durable; the local image is no longer needed.
    try write(Record(preview: nil, uploadedURL: uploaded), at: location)
    return uploaded
  }

  private func url(_ id: UUID, session: CommunitySession) -> URL {
    let digest = SHA256.hash(data: Data(session.sessionID.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return directory.appending(path: "\(session.accountID)/\(digest)/\(id).json")
  }

  private func read(_ url: URL) throws -> Record? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
  }

  private func write(_ record: Record, at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try JSONEncoder().encode(record).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
}

private enum Constants {
  static let maximumInputBytes = 32 * 1024 * 1024
  static let maximumUploadPixels = 2048
  static let jpegQuality: CGFloat = 0.85
}
