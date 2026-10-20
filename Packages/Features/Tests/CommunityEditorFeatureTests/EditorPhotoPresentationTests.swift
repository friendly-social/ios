@testable import CommunityEditorFeature
import CommunityProfileService
import CustomDump
import Dependencies
import Foundation
import Testing
import UIKit

@MainActor struct EditorPhotoPresentationTests {
  @Test func decodedAttachmentDoesNotRestoreLegacyBitmapBounds() throws {
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    photo.bounds = CGRect(x: 0, y: -8, width: 280, height: 168)
    let data = try NSKeyedArchiver.archivedData(withRootObject: photo, requiringSecureCoding: true)
    let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: PhotoAttachment.self, from: data)
    let restored = try #require(decoded)
    expectNoDifference(restored.bounds, .zero)
    #expect(restored.usesTextAttachmentView && restored.allowsTextAttachmentView)
    #expect(restored.image != nil)
  }

  @Test func providerFitsImagesToNarrowTextContainers() throws {
    let size = CGSize(width: 200, height: 120)
    let image = UIGraphicsImageRenderer(size: size).image { $0.fill(CGRect(origin: .zero, size: size)) }
    let photo = PhotoAttachment(id: UUID(), preview: image)
    let storage = NSTextContentStorage()
    let location = storage.documentRange.location
    let container = NSTextContainer(size: CGSize(width: 220, height: 400))
    let provider = try #require(photo.viewProvider(for: nil, location: location, textContainer: container))
    for (width, expectedWidth) in [(220.0, 210.0), (340.0, 280.0), (220.0, 210.0)] {
      container.size.width = width
      let bounds = provider.attachmentBounds(for: [:], location: location, textContainer: container,
        proposedLineFragment: CGRect(x: 0, y: 0, width: width, height: 400), position: .zero)
      expectNoDifference(bounds.size, CGSize(width: expectedWidth, height: expectedWidth * 0.6))
    }
  }

  @Test func retryOnOneAttachmentRetriesAllFailedSourcesOnce() async throws {
    let client = RetryPhotoClient()
    let editor = withDependencies { $0[EditorPhotoService.self] = client.service } operation: { makeEditor("") }
    editor.model.start(session: .init(accountID: 7, token: "token", sessionID: "session"))
    let photos = makePhotos()
    photos.forEach { editor.model.insertPhoto($0) }
    await waitFor { photos[0].presentation.state == .failed && photos[1].presentation.state == .failed }
    let callback = try #require(photos[1].presentation.retry)
    callback()
    await waitFor { photos.allSatisfy(\.ready) }
    let calls = await client.calls
    expectNoDifference(calls, [photos[0].sourceID: 2, photos[1].sourceID: 2])
    expectNoDifference(photos[0].sourceURL, photos[2].sourceURL)
    #expect(photos.allSatisfy { if case .uploaded = $0.presentation.state { return true }; return false })
    #expect(editor.model.canPublish)
  }

  @Test func providerObservesPreviewAndStateWithoutChangingAttachmentBounds() async throws {
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    photo.presentation.state = .uploading
    let view = try attachmentView(photo)
    let spinner = try #require(element("community.photoUploading", in: view) as? UIActivityIndicatorView)
    let retry = try #require(element("community.retryPhoto", in: view) as? UIButton)
    #expect(spinner.isAnimating && retry.isHidden)
    let originalBounds = photo.displayBounds(in: nil)
    photo.presentation.state = .failed
    await waitFor { !retry.isHidden && !spinner.isAnimating }
    var retries = 0
    photo.presentation.retry = { retries += 1 }
    retry.sendActions(for: .touchUpInside)
    expectNoDifference(retries, 1)
    photo.presentation.state = .uploaded(URL(string: "https://example.com/photo.jpg")!)
    await waitFor { retry.isHidden }
    expectNoDifference(photo.displayBounds(in: nil), originalBounds)
    let image = PhotoImagePreview.placeholder(maximumPixels: 30)
    photo.setPreview(image)
    let imageView = try #require(element("community.editorPhoto", in: view) as? UIImageView)
    await waitFor { imageView.image === image }
    #expect(photo.image === image && imageView.contentMode == .scaleAspectFit)
  }

  @Test(arguments: [CGSize(width: 20, height: 2000), CGSize(width: 2000, height: 20)])
  func extremeAspectRatiosHaveUsableRetryTarget(size: CGSize) throws {
    let image = UIGraphicsImageRenderer(size: size).image { $0.fill(CGRect(origin: .zero, size: size)) }
    let photo = PhotoAttachment(id: UUID(), preview: image)
    photo.presentation.state = .failed
    let container = NSTextContainer(size: CGSize(width: 340, height: 1000))
    let bounds = photo.displayBounds(in: container)
    let view = try attachmentView(photo)
    view.frame = CGRect(origin: .zero, size: bounds.size)
    view.layoutIfNeeded()
    let retry = try #require(element("community.retryPhoto", in: view) as? UIButton)
    #expect(view.bounds.contains(retry.frame))
    #expect(retry.frame.width >= 44 && retry.frame.height >= 44)
    #expect(view.hitTest(retry.center, with: nil)?.isDescendant(of: retry) == true)
    #expect(view.hitTest(CGPoint(x: 1, y: 1), with: nil) == nil)
  }

  @Test func attachmentControlsDoNotRetainEditorOrView() throws {
    weak var releasedModel: CommunityEditorViewModel?
    weak var releasedView: PhotoAttachmentView?
    let photo = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    photo.ready = true
    photo.sourceURL = URL(string: "https://example.com/photo.jpg")!
    try autoreleasepool {
      let editor = makeEditor("")
      editor.model.insertPhoto(photo)
      releasedModel = editor.model
      let view = try attachmentView(photo)
      releasedView = view
    }
    #expect(releasedModel == nil)
    #expect(releasedView == nil)
    photo.presentation.retry?()
  }
}

private extension EditorPhotoPresentationTests {
  private func makePhotos() -> [PhotoAttachment] {
    let first = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    let second = PhotoAttachment(id: UUID(), preview: PhotoImagePreview.placeholder())
    let copy = PhotoAttachment(id: UUID(), sourceID: first.sourceID, preview: PhotoImagePreview.placeholder())
    let ready = PhotoAttachment(id: UUID(), sourceURL: URL(string: "https://example.com/ready.jpg"),
      preview: PhotoImagePreview.placeholder())
    ready.ready = true
    return [first, second, copy, ready]
  }

  private func attachmentView(_ photo: PhotoAttachment) throws -> PhotoAttachmentView {
    let storage = NSTextContentStorage()
    let provider = try #require(photo.viewProvider(for: nil, location: storage.documentRange.location, textContainer: nil))
    #expect(provider.tracksTextAttachmentViewBounds)
    return try #require(provider.view as? PhotoAttachmentView)
  }

  private func descendants(in view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + descendants(in: $0) }
  }

  private func element(_ identifier: String, in view: UIView) -> UIView? {
    if view.accessibilityIdentifier == identifier { return view }
    return view.subviews.lazy.compactMap { element(identifier, in: $0) }.first
  }

  private func waitFor(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
      if condition() { return }
      await Task.yield()
    }
    #expect(condition())
  }
}

private actor RetryPhotoClient {
  private(set) var calls: [UUID: Int] = [:]

  nonisolated var service: EditorPhotoService {
    var service = EditorPhotoService.testValue
    service.restore = { _, fallback, _ in .init(preview: fallback ?? Data()) }
    service.upload = { id, _ in try await self.upload(id) }
    return service
  }

  private func upload(_ id: UUID) throws -> URL {
    calls[id, default: 0] += 1
    if calls[id] == 1 { throw EditorPhotoError.unavailable }
    return URL(string: "https://example.com/\(id).jpg")!
  }
}
