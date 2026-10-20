@testable import CommunityEditorFeature
import CustomDump
import Dependencies
import Foundation
import Synchronization
import Testing
import UIKit

@MainActor struct EditorPhotoReloadTests {
  @Test func pastedRemotePhotoWithoutPreviewStartsLoadingImmediately() async throws {
    let calls = Mutex(0)
    let data = try #require(portraitImage().pngData())
    var service = EditorPhotoService.testValue
    service.preview = { _ in calls.withLock { $0 += 1 }; return data }
    let editor = withDependencies { $0[EditorPhotoService.self] = service } operation: { makeEditor("") }
    let photo = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/pasted.jpg"))
    photo.ready = true
    editor.model.registerPastedPhoto(photo)
    for _ in 0..<1000 {
      if photo.hasLoadedPreview { break }
      await Task.yield()
    }
    #expect(photo.hasLoadedPreview)
    expectNoDifference(calls.withLock { $0 }, 1)
  }

  @Test func sourceReloadSharesRunningPreviewAndReceivesItsResult() async throws {
    let preview = ControlledPreview()
    var service = EditorPhotoService.testValue
    service.preview = { _ in await preview.load() }
    let editor = withDependencies { $0[EditorPhotoService.self] = service } operation: {
      makeEditor("![](https://example.com/photo.jpg)")
    }
    await preview.waitUntilStarted()
    editor.model.source += "\n\nAfter"
    editor.model.loadSource(editor.model.source)
    for _ in 0..<20 { await Task.yield() }
    let image = portraitImage()
    await preview.finish(try #require(image.pngData()))
    let photo = try #require(editor.model.text.attribute(.attachment, at: 0,
      effectiveRange: nil) as? PhotoAttachment)
    for _ in 0..<1000 {
      if photo.image?.size.height == 200 { break }
      await Task.yield()
    }
    expectNoDifference(photo.image?.size, image.size)
    #expect(photo.hasLoadedPreview)
    let calls = await preview.calls
    expectNoDifference(calls, 1)
  }

  @Test(arguments: [false, true], [false, true])
  func sourceReloadKeepsLoadedImage(local: Bool, changed: Bool) throws {
    let editor = makeEditor("**Before**")
    let image = portraitImage()
    let photo = PhotoAttachment(id: UUID(), preview: image)
    if !local {
      photo.sourceURL = URL(string: "https://example.com/photo.jpg")!
      photo.ready = true
    }
    editor.model.insertPhoto(photo)
    let source = editor.model.markdown + (changed ? "\n\n**After**" : "")
    editor.model.source = source
    editor.model.loadSource(source)
    let restored = try #require(editor.model.text.attribute(.attachment, at: 0,
      effectiveRange: nil) as? PhotoAttachment)
    #expect(restored.image === image)
    #expect(restored.hasLoadedPreview)
    expectNoDifference(restored.displayBounds(in: nil), photo.displayBounds(in: nil))
    expectNoDifference(restored.ready, photo.ready)
    expectNoDifference(editor.model.markdown, source)
  }
}

private extension EditorPhotoReloadTests {
  private func portraitImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image {
      $0.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
    }
  }
}

private actor ControlledPreview {
  private(set) var calls = 0
  private var completions: [CheckedContinuation<Data, Never>] = []
  private var started: CheckedContinuation<Void, Never>?

  func load() async -> Data {
    calls += 1
    return await withCheckedContinuation {
      completions.append($0)
      started?.resume()
      started = nil
    }
  }

  func waitUntilStarted() async {
    if calls > 0 { return }
    await withCheckedContinuation { started = $0 }
  }

  func finish(_ data: Data) {
    completions.forEach { $0.resume(returning: data) }
    completions.removeAll()
  }
}
