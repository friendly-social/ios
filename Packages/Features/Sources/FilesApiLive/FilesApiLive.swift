import Dependencies
import FilesApi
import Foundation
import Models
import Networking

struct FilesApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func upload(_ data: Data) async throws -> FileDescriptor {
    let boundary = "Boundary-\(UUID().uuidString)"
    let request = HTTPClient.Request(
      path: "files/upload",
      method: .post,
      headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"])
    do {
      let response = try await client.upload(request, data: multipart(data, boundary: boundary))
      guard response.statusCode == 200 else {
        throw FilesApi.Error.serverError(statusCode: response.statusCode)
      }
      let body: FileDescriptorResponse = try client.decode(response)
      return try body.domain()
    } catch let error as FilesApi.Error {
      throw error
    } catch {
      throw FilesApi.Error.ioError(error)
    }
  }

  func downloadURL(for request: FilesApi.DownloadRequest) -> URL {
    client.baseURL.appending(
      path: "files/download/\(request.id)/\(request.accessHash)")
  }
}

private extension FilesApiLive {
  private func multipart(_ data: Data, boundary: String) -> Data {
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data(
      "Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"; size=\(data.count)\r\n".utf8))
    body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
    body.append(data)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    return body
  }
}

private struct FileDescriptorResponse: Decodable {
  let id: Int64
  let accessHash: String

  func domain() throws -> FileDescriptor {
    try FileDescriptor(id: FileId(id), accessHash: FileAccessHash(accessHash))
  }
}
