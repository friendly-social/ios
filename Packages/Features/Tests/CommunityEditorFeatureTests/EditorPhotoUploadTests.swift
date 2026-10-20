@testable import CommunityEditorFeature
@testable import CommunityEditorFeatureLive
import CommunityProfileService
import CustomDump
import Dependencies
import Foundation
import Testing
import UIKit

@MainActor struct EditorPhotoUploadTests {
  private let session = CommunitySession(accountID: 7, token: "token", sessionID: "session")
  private let url = URL(string: "https://example.com/uploaded.jpg")!

  @Test func knownSourcesDoNotSerializeFallbackAgain() async {
    let uploads = EditorPhotoUploads()
    let id = UUID()
    let url = url
    var service = EditorPhotoService.testValue
    service.restore = { _, _, _ in .init(preview: Data(), uploadedURL: url) }
    var encodings = 0
    func fallback() -> Data? {
      encodings += 1
      return Data()
    }
    uploads.start(id, fallback: fallback(), session: session, service: service)
    uploads.start(id, fallback: fallback(), session: session, service: service)
    uploads.retry(id, fallback: fallback(), session: session, service: service)
    expectNoDifference(encodings, 1)
    await waitFor { uploads.states.wrappedValue[id] == .uploaded(url) }
    uploads.start(id, fallback: fallback(), session: session, service: service)
    uploads.retry(id, fallback: fallback(), session: session, service: service)
    expectNoDifference(encodings, 1)
  }

  @Test func pendingClipboardCopiesShareOneUploadAndLateCopiesReuseURL() async throws {
    let client = ControlledPhotoClient()
    let editor = withDependencies { $0[EditorPhotoService.self] = client.service } operation: { makeEditor("Before") }
    editor.model.start(session: session)
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    editor.model.insertPhoto(photo)
    await client.waitUntilStarted()
    let fragment = try #require(PhotoFragment(NSAttributedString(attachment: photo)).attributedText())
    let copy = try #require(fragment.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    editor.model.insertPhoto(copy)
    #expect(!editor.model.canPublish)
    let calls1 = await client.calls
    expectNoDifference(calls1, 1)
    await client.finish(url)
    await waitFor { photo.ready && copy.ready }
    let stale = try #require(PhotoFragment(fragment).attributedText())
    let lateCopy = try #require(stale.attribute(.attachment, at: 0, effectiveRange: nil) as? PhotoAttachment)
    lateCopy.ready = false
    lateCopy.sourceURL = PhotoAttachment.localURL(photo.sourceID)
    editor.model.insertPhoto(lateCopy)
    await waitFor { lateCopy.ready }
    expectNoDifference(lateCopy.sourceURL, url)
    let calls2 = await client.calls
    expectNoDifference(calls2, 1)
    #expect(editor.model.canPublish)
  }

  @Test func failedUploadBlocksPublicationAndRetryKeepsSource() async throws {
    let client = ControlledPhotoClient()
    let editor = withDependencies { $0[EditorPhotoService.self] = client.service } operation: { makeEditor("") }
    editor.model.start(session: session)
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    editor.model.insertPhoto(photo)
    await client.waitUntilStarted()
    await client.fail()
    await waitFor { photo.presentation.state == .failed }
    #expect(!editor.model.canPublish)
    editor.model.retryPhotos()
    await client.waitUntilStarted()
    let calls3 = await client.calls
    expectNoDifference(calls3, 2)
    await client.finish(url)
    await waitFor { photo.ready }
    #expect(editor.model.canPublish)
    expectNoDifference(photo.presentation.state, .uploaded(url))
  }

  @Test func reopeningLocalDraftUsesPersistedURL() async throws {
    let id = UUID()
    let client = ControlledPhotoClient(restoredURL: url)
    let model = withDependencies { $0[EditorPhotoService.self] = client.service } operation: {
      CommunityEditorViewModel(source: "Before\n\n![cat](\(PhotoAttachment.localURL(id)))\n\nAfter")
    }
    model.start(session: session)
    await waitFor { !model.markdown.contains("friendly-photo:") }
    expectNoDifference(model.markdown, "Before\n\n![cat](\(url))\n\nAfter")
    let calls4 = await client.calls
    expectNoDifference(calls4, 0)
    #expect(model.canPublish)
  }

  @Test func storageSurvivesRestartAndIsolatesSession() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = url
    let store = EditorPhotoStore(directory: directory)
    let id = UUID()
    let data = try #require(PhotoImagePreview.placeholder().pngData())
    _ = try await store.restore(id, fallback: data, session: session)
    _ = try await store.upload(id, session: session) { _ in url }
    let reopened = EditorPhotoStore(directory: directory)
    let restored = try await reopened.restore(id, fallback: nil, session: session)
    expectNoDifference(restored.uploadedURL, url)
    #expect(restored.preview.isEmpty)
    let same = try await reopened.upload(id, session: session) { _ in
      Issue.record("A completed source must never be uploaded again")
      return url
    }
    expectNoDifference(same, url)
    let other = CommunitySession(accountID: 7, token: "token", sessionID: "other")
    await #expect(throws: EditorPhotoError.missingOriginal) {
      try await reopened.restore(id, fallback: nil, session: other)
    }
  }

  @Test func invalidImageIsRejectedBeforeUpload() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = EditorPhotoStore(directory: directory)
    await #expect(throws: EditorPhotoError.invalidImage) {
      try await store.restore(UUID(), fallback: Data("not an image".utf8), session: session)
    }
  }

  @Test func formattingUndoDoesNotRetainEditor() {
    weak var released: CommunityEditorViewModel?
    do {
      let editor = makeEditor("hello")
      released = editor.model
      editor.model.setSelection(NSRange(location: 0, length: 5))
      editor.model.toggle(.bold)
    }
    #expect(released == nil)
  }
}

private extension EditorPhotoUploadTests {
  private func waitFor(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
      if condition() { return }
      await Task.yield()
    }
    #expect(condition())
  }
}

private actor ControlledPhotoClient {
  private(set) var calls = 0
  private var completion: CheckedContinuation<URL, Error>?
  private var started: CheckedContinuation<Void, Never>?
  private let restoredURL: URL?

  init(restoredURL: URL? = nil) { self.restoredURL = restoredURL }

  nonisolated var service: EditorPhotoService {
    .init(
      selectionData: { _ in throw EditorPhotoError.unavailable },
      restore: { _, fallback, _ in
        await self.content(fallback: fallback)
      },
      upload: { _, _ in try await self.upload() },
      preview: { _ in throw EditorPhotoError.unavailable },
      cachedPreview: { _ in nil }
    )
  }

  private func content(fallback: Data?) -> EditorPhotoContent {
    .init(preview: fallback ?? Data(), uploadedURL: restoredURL)
  }

  private func upload() async throws -> URL {
    calls += 1
    return try await withCheckedThrowingContinuation {
      completion = $0
      started?.resume()
      started = nil
    }
  }

  func waitUntilStarted() async {
    if completion != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func finish(_ url: URL) { completion?.resume(returning: url); completion = nil }

  func fail() { completion?.resume(throwing: EditorPhotoError.unavailable); completion = nil }
}
