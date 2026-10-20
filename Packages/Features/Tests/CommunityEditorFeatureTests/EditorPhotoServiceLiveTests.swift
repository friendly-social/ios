@testable import CommunityEditorFeature
@testable import CommunityEditorFeatureLive
import CommunityProfileService
import CustomDump
import Dependencies
import FilesApi
import FilesApiLive
import Foundation
import ImageService
@testable import ImageServiceLive
import Models
import Networking
import Nuke
import Synchronization
import Testing
import UIKit

@MainActor struct EditorPhotoServiceLiveTests {
  private let session = CommunitySession(accountID: 7, token: "token", sessionID: "session")
  private let url = URL(string: "https://example.com/uploaded.jpg")!

  @Test func corruptStoredPhotoKeepsFeatureErrorContract() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = try liveClient(directory: directory, files: FilesApi())
    let id = UUID()
    _ = try await live.restore(id, fallback: imageData(), session: session)
    let files = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
    let record = try #require(files.allObjects.compactMap { $0 as? URL }.first { $0.pathExtension == "json" })
    try Data("corrupt".utf8).write(to: record)
    await #expect(throws: EditorPhotoError.unavailable) {
      try await live.restore(id, fallback: nil, session: session)
    }
  }

  @Test func blockedPhotoDirectoryKeepsFeatureErrorContract() async throws {
    let parent = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: parent) }
    let directory = parent.appending(component: "Photos")
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    try Data().write(to: directory)
    var profile = CommunityProfileService()
    profile.isCurrentSession = { _ in true }
    let blocked = withDependencies { $0[CommunityProfileService.self] = profile } operation: {
      EditorPhotoServiceLive(directory: directory)
    }
    await #expect(throws: EditorPhotoError.unavailable) {
      try await blocked.restore(UUID(), fallback: imageData(), session: session)
    }
  }

  @Test func restorePreservesMissingOriginalAndInvalidImageErrors() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = try liveClient(directory: directory, files: FilesApi())
    await #expect(throws: EditorPhotoError.missingOriginal) {
      try await live.restore(UUID(), fallback: nil, session: session)
    }
    await #expect(throws: EditorPhotoError.invalidImage) {
      try await live.restore(UUID(), fallback: Data("invalid".utf8), session: session)
    }
  }

  @Test func invalidPreviewURLKeepsFeatureErrorContract() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = try liveClient(directory: directory, files: FilesApi())
    do {
      _ = try await live.preview(URL(fileURLWithPath: "/image.jpg"))
      Issue.record("Expected invalid image error for a file URL")
    } catch EditorPhotoError.invalidImage {}
  }

  @Test func uploadedImageIsAvailableInNewEditorBeforeMount() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = try liveClient(directory: directory, files: recordingFiles(UploadRecorder(file: try fileDescriptor())))
    let id = UUID()
    let content = try await live.restore(id, fallback: imageData(), session: session)
    let uploaded = try await live.upload(id, session: session)
    let service = photoClient(live)
    let model = withDependencies { $0[EditorPhotoService.self] = service } operation: {
      CommunityEditorViewModel(source: "![](\(uploaded))")
    }
    model.start(session: session)
    let photo = try #require(model.text.attribute(.attachment, at: 0,
      effectiveRange: nil) as? PhotoAttachment)
    #expect(photo.hasLoadedPreview)
    let image = try #require(UIImage(data: content.preview))
    let bounds = photo.displayBounds(in: nil)
    expectNoDifference(bounds.height / bounds.width, image.size.height / image.size.width)
  }

  @Test func productionUploadSendsSessionAndOriginalFileSize() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let transport = HTTPTransport(data: { _ in throw URLError(.unsupportedURL) }, upload: { request, body in
      expectNoDifference(request.url?.path, "/files/upload")
      expectNoDifference(request.httpMethod, "POST")
      expectNoDifference(request.value(forHTTPHeaderField: "X-User-Id"), "7")
      expectNoDifference(request.value(forHTTPHeaderField: "X-Token"), "token")
      let size = try #require(request.value(forHTTPHeaderField: "X-File-Size").flatMap(Int.init))
      let content = try Self.multipartContent(request, body: body)
      expectNoDifference(size, content.count)
      #expect(content.starts(with: [0xff, 0xd8]))
      return Self.uploadResponse(status: 200)
    })
    let live = try liveClient(directory: directory, files: filesClient(transport))
    let id = UUID()
    _ = try await live.restore(id, fallback: imageData(), session: session)
    let uploaded = try await live.upload(id, session: session)
    expectNoDifference(uploaded.absoluteString,
      "https://example.com/files/download/1200/" + String(repeating: "a", count: 256))
  }

  @Test(arguments: [400, 401, 503]) func rejectedUploadKeepsOriginalForRetry(status: Int) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let rejected = Mutex(true)
    let transport = HTTPTransport(data: { _ in throw URLError(.unsupportedURL) }, upload: { _, _ in
      Self.uploadResponse(status: rejected.withLock { $0 } ? status : 200)
    })
    let live = try liveClient(directory: directory, files: filesClient(transport))
    let id = UUID()
    let original = try await live.restore(id, fallback: imageData(), session: session)
    await #expect(throws: EditorPhotoError.unavailable) { try await live.upload(id, session: session) }
    let pending = try await live.restore(id, fallback: nil, session: session)
    expectNoDifference(pending.preview, original.preview)
    expectNoDifference(pending.uploadedURL, nil)
    rejected.withLock { $0 = false }
    let uploaded = try await live.upload(id, session: session)
    let completed = try await live.restore(id, fallback: nil, session: session)
    expectNoDifference(completed.uploadedURL, uploaded)
  }

  @Test func liveServicePreparesJPEGAndUsesFilesAPIOnce() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let uploads = UploadRecorder(file: try fileDescriptor())
    let live = try liveClient(directory: directory, files: recordingFiles(uploads))
    let id = UUID()
    let source = try imageData()
    _ = try await live.restore(id, fallback: source, session: session)
    let first = try await live.upload(id, session: session)
    let second = try await live.upload(id, session: session)
    expectNoDifference(first, url)
    expectNoDifference(second, url)
    let data = await uploads.values
    expectNoDifference(data.count, 1)
    let jpeg = try #require(data.first)
    #expect(jpeg.starts(with: [0xff, 0xd8]))
    let image = try #require(UIImage(data: jpeg))
    #expect(max(image.size.width, image.size.height) <= 2048)
  }

  @Test func expiredSessionCannotStartOrFinishUpload() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let current = Mutex(true)
    let upload = LateUpload()
    var files = FilesApi()
    files.uploadAuthorized = { _, _ in try await upload.wait() }
    files.downloadURL = { _ in URL(string: "https://example.com/photo.jpg")! }
    let live = try liveClient(directory: directory, files: files, isCurrent: { current.withLock { $0 } })
    let id = UUID()
    let data = try #require(UIImage(systemName: "photo")?.pngData())
    _ = try await live.restore(id, fallback: data, session: session)
    let task = Task { try await live.upload(id, session: session) }
    await upload.started()
    current.withLock { $0 = false }
    await upload.finish()
    await #expect(throws: CancellationError.self) { try await task.value }
    await #expect(throws: CancellationError.self) { try await live.upload(id, session: session) }
  }
}

private extension EditorPhotoServiceLiveTests {
  private func photoClient(_ live: EditorPhotoServiceLive) -> EditorPhotoService {
    .init(
      selectionData: { try await live.selectionData($0) },
      restore: { try await live.restore($0, fallback: $1, session: $2) },
      upload: { try await live.upload($0, session: $1) },
      preview: { try await live.preview($0) },
      cachedPreview: { live.cachedPreview($0) }
    )
  }

  private func filesClient(_ transport: HTTPTransport) -> FilesApi {
    let client = HTTPClient(baseURL: URL(string: "https://example.com")!, transport: transport)
    return withDependencies { $0[HTTPClient.self] = client } operation: { FilesApi.liveValue }
  }

  nonisolated private static func uploadResponse(status: Int) -> HTTPResponse {
    let hash = String(repeating: "a", count: 256)
    return .init(data: Data("{\"id\":1200,\"accessHash\":\"\(hash)\"}".utf8), statusCode: status)
  }

  nonisolated private static func multipartContent(_ request: URLRequest, body: Data) throws -> Data {
    let type = try #require(request.value(forHTTPHeaderField: "Content-Type"))
    let boundary = try #require(type.components(separatedBy: "boundary=").last)
    let start = try #require(body.range(of: Data("\r\n\r\n".utf8)))
    let end = try #require(body.range(of: Data("\r\n--\(boundary)--\r\n".utf8)))
    return body.subdata(in: start.upperBound..<end.lowerBound)
  }

  private func recordingFiles(_ recorder: UploadRecorder) -> FilesApi {
    let url = url
    var files = FilesApi()
    files.uploadAuthorized = { data, credentials in
      expectNoDifference(credentials, .init(accountID: 7, token: "token"))
      return await recorder.upload(data)
    }
    files.downloadURL = { request in
      expectNoDifference(request.id, 1200)
      return url
    }
    return files
  }

  private func liveClient(
    directory: URL, files: FilesApi, isCurrent: @escaping @Sendable () -> Bool = { true }
  ) throws -> EditorPhotoServiceLive {
    let session = session
    var profile = CommunityProfileService()
    profile.isCurrentSession = { $0 == session && isCurrent() }
    let cache = try DataCache(path: directory.appending(path: "Previews"))
    let pipeline = ImagePipeline { configuration in
      configuration.dataCache = cache
      configuration.imageCache = ImageCache()
    }
    let images = ImageServiceLive(pipeline: pipeline)
    return withDependencies {
      $0[ImageService.self] = .init(prepare: { images.prepare() }, load: { try await images.load($0) },
        cached: { images.cached($0) }, remember: { images.remember($0, for: $1) })
      $0[FilesApi.self] = files
      $0[CommunityProfileService.self] = profile
    } operation: {
      EditorPhotoServiceLive(directory: directory)
    }
  }

  private func imageData() throws -> Data {
    try #require(UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500)).image {
      $0.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
    }.pngData())
  }

  private func fileDescriptor() throws -> FileDescriptor {
    try FileDescriptor(id: FileId(1200), accessHash: FileAccessHash(String(repeating: "a", count: 256)))
  }
}

private actor UploadRecorder {
  private(set) var values: [Data] = []
  private let file: FileDescriptor
  init(file: FileDescriptor) { self.file = file }

  func upload(_ data: Data) -> FileDescriptor { values.append(data); return file }
}

private actor LateUpload {
  private var completion: CheckedContinuation<FileDescriptor, Error>?
  private var start: CheckedContinuation<Void, Never>?

  func wait() async throws -> FileDescriptor {
    try await withCheckedThrowingContinuation {
      completion = $0
      start?.resume()
      start = nil
    }
  }

  func started() async {
    if completion != nil { return }
    await withCheckedContinuation { start = $0 }
  }

  func finish() {
    let file = try! FileDescriptor(id: FileId(1200), accessHash: FileAccessHash(String(repeating: "a", count: 256)))
    completion?.resume(returning: file)
    completion = nil
  }
}
