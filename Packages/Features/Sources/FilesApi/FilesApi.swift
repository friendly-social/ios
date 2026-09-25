import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct FilesApi: Sendable {
  public var upload: @Sendable (Data) async throws -> FileDescriptor
  public var downloadURL: @Sendable (DownloadRequest) -> URL = { _ in URL(fileURLWithPath: "/") }

  public enum Error: Swift.Error {
    case ioError(Swift.Error)
    case serverError(statusCode: Int)
  }
}

extension FilesApi {
  public struct DownloadRequest: Sendable {
    public let id: Int64
    public let accessHash: String

    public init(id: Int64, accessHash: String) {
      self.id = id
      self.accessHash = accessHash
    }
  }
}

extension FilesApi {
  public func downloadURL(for descriptor: FileDescriptor) -> URL {
    downloadURL(.init(id: descriptor.id.int64, accessHash: descriptor.accessHash.string))
  }
}
