import CommunityDraftService
@testable import CommunityEditorFeature
@testable import CommunityFeature
import CommunityService
import Dependencies
import Foundation
import Testing

@MainActor struct CommunityPhotoPublicationTests {
  private let pending = "![cat](friendly-photo://11111111-1111-1111-1111-111111111111)"

  @Test func composerDoesNotSubmitUnfinishedPhoto() async {
    var service = CommunityService()
    service.publish = { _ in Issue.record("Pending photo was published"); return .init(id: 1, accessHash: "a") }
    let model = withDependencies {
      $0[EditorPhotoService.self] = missingPhotoClient()
    } operation: {
      makeComposerModel(service: service, drafts: .init(load: { .init(content: pending) }, save: { _ in }, remove: {}))
    }
    await model.restore()
    #expect(!model.canPublish)
    await model.publish()
    #expect(model.published == nil)
    model.stop()
  }

  @Test func replyDoesNotSubmitPendingPhotoWithEditorClosed() async throws {
    var service = CommunityService()
    service.reply = { _, _ in Issue.record("Pending reply was submitted"); return .init(id: 2, accessHash: "b") }
    let post = CommunityPost.awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "a"), text: "Post", owner: nil, date: .now))
    let model = withDependencies {
      $0[EditorPhotoService.self] = missingPhotoClient()
    } operation: { makeDetailModel(post: post, service: service) }
    let composer = try #require(model.replyComposer)
    await composer.restore()
    composer.editor.loadSource(pending)
    #expect(!composer.canPublish)
    await composer.publish()
    #expect(!composer.isPublishing && model.destination?.composer == nil)
    model.stop()
  }

  @Test func editStartsPhotoSessionAndCannotSavePendingImage() {
    let post = CommunityPost.awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "a"), text: "Old post", owner: nil, date: .now))
    let model = withDependencies {
      $0[EditorPhotoService.self] = missingPhotoClient()
    } operation: { makeEditModel(post: post, service: CommunityService()) }
    #expect(model.editor.canInsertPhoto)
    model.editor.loadSource(pending)
    #expect(!model.canSave)
    model.stop()
  }

  @Test func completedPhotoLinkPassesPublicationValidation() {
    #expect(CommunityEditorViewModel.isPublishable("![cat](https://example.com/photo.jpg)"))
    #expect(CommunityEditorViewModel.isPublishable("`![](friendly-photo://11111111-1111-1111-1111-111111111111)`"))
    #expect(!CommunityEditorViewModel.isPublishable(pending))
  }
}

private extension CommunityPhotoPublicationTests {
  private func missingPhotoClient() -> EditorPhotoService {
    var client = EditorPhotoService.testValue
    client.restore = { _, _, _ in throw EditorPhotoError.missingOriginal }
    client.upload = { _, _ in throw EditorPhotoError.unavailable }
    return client
  }
}
