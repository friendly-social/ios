import CommunityApi
import CommunityDraftService
@testable import CommunityApiLive
@testable import CommunityFeature
import CommunityService
import CommunityServiceLive
import Foundation
import Testing

@MainActor
struct CommunityMutationTests {
  @Test func editPreservesMetadataAndExactMarkdown() async throws {
    let original = try post()
    let source = "  # План\n\n| A | B |\n|---|---|\n| 1 | 2 |\n"
    var saved: CommunityPost?
    let state = MutationTestState()
    let model = makeEditModel(post: original, service: service(edit: { id, text in
      #expect(id == 42)
      #expect(text == source)
      await state.incrementCalls()
    }), onSaved: { saved = $0 })
    #expect(model.editor.markdown == original.text)
    #expect(!model.canSave)
    model.editor.loadSource(source)
    await model.saveButtonTapped()
    await model.saveButtonTapped()
    #expect(state.calls == 1)
    #expect(model.isSaved)
    #expect(saved?.text == source)
    #expect(saved?.edited == true)
    #expect(saved?.owner?.id == original.owner?.id)
    #expect(saved?.date == original.date)
    #expect(saved?.accessHash == original.accessHash)
  }

  @Test func invalidAndUnchangedEditNeverSends() async throws {
    let state = MutationTestState()
    let model = makeEditModel(post: try post(), service: service(edit: { _, _ in await state.incrementCalls() }))
    await model.saveButtonTapped()
    model.editor.loadSource(" \n")
    await model.saveButtonTapped()
    model.editor.loadSource(String(repeating: "😀", count: 2049))
    await model.saveButtonTapped()
    #expect(state.calls == 0)
  }

  @Test func failedEditKeepsTextWithoutAutomaticRetry() async throws {
    let state = MutationTestState()
    let model = makeEditModel(post: try post(), service: service(edit: { _, _ in
      await state.incrementCalls()
      throw CommunityError.outcomeUnknown
    }))
    model.editor.loadSource("Изменения")
    await model.saveButtonTapped()
    #expect(state.calls == 1)
    #expect(model.editor.markdown == "Изменения")
    #expect(model.requiresRetryConfirmation)
    #expect(!model.isSaved)
    #expect(model.canSave)
    #expect(model.error != nil)
  }

  @Test func duplicateSaveAndLateSessionResponseAreIgnored() async throws {
    let state = MutationTestState()
    var saved = false
    let model = makeEditModel(post: try post(), service: service(edit: { _, _ in
      await state.incrementCalls()
      await state.waitForVoidCompletion()
    }), isCurrentSession: { state.current }, onSaved: { _ in saved = true })
    model.editor.loadSource("Новый текст")
    let task = Task { await model.saveButtonTapped() }
    await withCheckedContinuation { state.started = $0 }
    await model.saveButtonTapped()
    #expect(state.calls == 1)
    state.current = false
    state.voidCompletion?.resume()
    await task.value
    #expect(!saved)
    #expect(!model.isSaved)
  }

  @Test func onlyOwnPostsCanBeManaged() async throws {
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(delete: { _ in await state.incrementCalls() }), drafts: drafts, accountID: 7)
    let other = try post(ownerID: 8)
    #expect(!model.canManage(other))
    model.editButtonTapped(other)
    await model.deleteConfirmed(other)
    #expect(model.editingPost == nil)
    #expect(state.calls == 0)
    #expect(model.canManage(try post()))
  }

  @Test func newlyPublishedPostCanBeEditedBeforeDetailsArrive() async throws {
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(
      list: { _ in throw CommunityError.unavailable },
      edit: { _, text in await state.recordEditedText(text) }
    ), drafts: drafts, accountID: 7)
    await model.didPublish(.init(id: 42, accessHash: "hash"), text: "Опубликован", warning: nil)
    model.stop()
    await model.load()
    let post = try #require(model.posts.first)
    guard case .awaitingDetails = post else { Issue.record("Expected local confirmed post"); return }
    #expect(model.canManage(post))
    model.editButtonTapped(post)
    let editor = try #require(model.editingPost)
    editor.editor.loadSource("Изменён")
    await editor.saveButtonTapped()
    #expect(state.editedText == "Изменён")
    #expect(model.notice == nil)
    #expect(model.posts.first?.text == "Изменён")
    #expect(model.posts.first?.date != nil)
    #expect(model.posts.first?.owner == nil)
  }

  @Test func newlyPublishedPostCanBeDeletedBeforeDetailsArrive() async throws {
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(delete: { id in await state.recordDeletedID(id) }), drafts: drafts, accountID: 7)
    await model.didPublish(.init(id: 42, accessHash: "hash"), text: "Опубликован", warning: nil)
    model.stop()
    let post = try #require(model.posts.first)
    await model.deleteConfirmed(post)
    #expect(state.deletedID == 42)
    #expect(model.posts.isEmpty)
    await model.load()
    #expect(model.posts.isEmpty)
  }

  @Test func hydrationDuringEditPreservesServerMetadata() async throws {
    let fullPost = try post()
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(
      list: { _ in .init(data: [fullPost], nextId: nil) },
      edit: { _, _ in await state.waitForVoidCompletion() }
    ), drafts: drafts, accountID: 7)
    await model.didPublish(fullPost.descriptor, text: "Опубликован", warning: nil)
    model.stop()
    let local = try #require(model.posts.first)
    model.editButtonTapped(local)
    let editor = try #require(model.editingPost)
    editor.editor.loadSource("Правка")
    let save = Task { await editor.saveButtonTapped() }
    await withCheckedContinuation { state.started = $0 }
    await model.load()
    #expect(model.posts.count == 1)
    state.voidCompletion?.resume()
    await save.value
    #expect(model.posts.first == fullPost.replacingText("Правка"))
  }

  @Test func deletedPostsCannotBeManagedOrEdited() async throws {
    let deleted = CommunityPost.deleted(.init(descriptor: .init(id: 42, accessHash: "hash"), date: .init(timeIntervalSince1970: 0)))
    let model = makeFeedModel(feedPreparation: .fixture, service: service(), drafts: drafts, accountID: 7)
    #expect(!model.canManage(deleted))
    model.editButtonTapped(deleted)
    #expect(model.editingPost == nil)
    let editor = makeEditModel(post: deleted, service: service())
    editor.editor.loadSource("Нельзя восстановить редактированием")
    #expect(!editor.canSave)
    #expect(deleted.replacingText("Text") == deleted)
  }

  @Test func successfulEditUpdatesFeedWithoutTouchingDraft() async throws {
    let original = try post()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in .init(data: [original], nextId: nil) }), drafts: drafts, accountID: 7)
    await model.load()
    model.editButtonTapped(original)
    let editor = try #require(model.editingPost)
    editor.editor.loadSource("Изменён")
    await editor.saveButtonTapped()
    #expect(model.posts.first?.text == "Изменён")
    #expect(model.posts.first?.edited == true)
    #expect(model.feedPosts.first?.content.source == "Изменён")
    #expect(model.feedPosts.first?.content.excerpt != nil)
  }

  @Test func deletionWaitsForSuccessAndRejectsDuplicateTap() async throws {
    let original = try post()
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in .init(data: [original], nextId: nil) }, delete: { id in
      #expect(id == original.id)
      await state.incrementCalls()
      await state.waitForVoidCompletion()
    }), drafts: drafts, accountID: 7)
    await model.load()
    let task = Task { await model.deleteConfirmed(original) }
    await withCheckedContinuation { state.started = $0 }
    #expect(model.posts.count == 1)
    #expect(model.deletingID == original.id)
    await model.deleteConfirmed(original)
    #expect(state.calls == 1)
    state.voidCompletion?.resume()
    await task.value
    #expect(model.posts.isEmpty)
    #expect(model.deletingID == nil)
    #expect(model.mutationError == nil)
  }

  @Test func failedDeletionKeepsCardAndReportsUncertainResult() async throws {
    let original = try post()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in .init(data: [original], nextId: nil) }, delete: { _ in throw CommunityError.outcomeUnknown }), drafts: drafts, accountID: 7)
    await model.load()
    await model.deleteConfirmed(original)
    #expect(model.posts.count == 1)
    #expect(model.mutationError != nil)
    #expect(model.deletingID == nil)
  }

  @Test func oldRefreshCannotRestoreDeletedPost() async throws {
    let original = try post()
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in
      await state.waitForPageCompletion()
    }), drafts: drafts, accountID: 7)
    let task = Task { await model.load() }
    await withCheckedContinuation { state.started = $0 }
    await model.deleteConfirmed(original)
    state.pageCompletion?.resume(returning: .init(data: [original], nextId: nil))
    await task.value
    #expect(model.posts.isEmpty)
    #expect(!model.isLoading)
  }

  @Test func mutationsExpireUnauthorizedSession() async throws {
    let original = try post()
    var expirations = 0
    let client = service(edit: { _, _ in throw CommunityError.unauthorized }, delete: { _ in throw CommunityError.unauthorized })
    let model = makeEditModel(post: original, service: client, onUnauthorized: { expirations += 1 })
    model.editor.loadSource("Изменения")
    await model.saveButtonTapped()
    let feed = makeFeedModel(feedPreparation: .fixture, service: client, drafts: drafts, accountID: 7, onUnauthorized: { expirations += 1 })
    await feed.deleteConfirmed(original)
    #expect(expirations == 2)
    #expect(!model.isSaved)
  }

  @Test func oldRefreshCannotOverwriteSavedEdit() async throws {
    let original = try post()
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in
      if await state.nextRequest() == 1 { return .init(data: [original], nextId: nil) }
      return await state.waitForPageCompletion()
    }), drafts: drafts, accountID: 7)
    await model.load()
    let task = Task { await model.load() }
    await withCheckedContinuation { state.started = $0 }
    model.editButtonTapped(original)
    let editor = try #require(model.editingPost)
    editor.editor.loadSource("Новый текст")
    await editor.saveButtonTapped()
    state.pageCompletion?.resume(returning: .init(data: [original], nextId: nil))
    await task.value
    #expect(model.posts.first?.text == "Новый текст")
    #expect(model.posts.first?.edited == true)
  }

  @Test func lateDeletionDoesNotUpdateExpiredSession() async throws {
    let original = try post()
    let state = MutationTestState()
    let model = makeFeedModel(feedPreparation: .fixture, service: service(list: { _ in .init(data: [original], nextId: nil) }, delete: { _ in
      await state.waitForVoidCompletion()
    }), drafts: drafts, accountID: 7, isCurrentSession: { state.current })
    await model.load()
    let task = Task { await model.deleteConfirmed(original) }
    await withCheckedContinuation { state.started = $0 }
    state.current = false
    state.voidCompletion?.resume()
    await task.value
    #expect(model.posts.count == 1)
    #expect(model.notice == nil)
  }
}

struct CommunityMutationHTTPTests {
  @Test(arguments: [401, 404, 500])
  func mutationErrorsAreClassified(status: Int) async throws {
    let client = makeCommunityApi { request in
      (Data(), try makeHTTPResponse(for: request, statusCode: status))
    }
    let expected: CommunityError = status == 401 ? .unauthorized : status == 404 ? .rejected(404) : .outcomeUnknown
    await #expect(throws: expected) {
      try await client.edit(id: 42, text: "Text", credentials: .init(accountID: 7, token: "test"))
    }
    await #expect(throws: expected) {
      try await client.delete(id: 42, credentials: .init(accountID: 7, token: "test"))
    }
  }

  @Test func editMatchesContractAndAcceptsEmptySuccessBody() async throws {
    let client = makeCommunityApi { request in
      #expect(request.url?.path == "/community/42/edit")
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
      #expect(request.value(forHTTPHeaderField: "X-Token") == "test-token")
      let data = try #require(request.httpBody)
      let body = try JSONDecoder().decode(EditBody.self, from: data)
      #expect(body.text.value == "**Текст**\n")
      return (Data(), try makeHTTPResponse(for: request, statusCode: 200))
    }
    try await client.edit(id: 42, text: "**Текст**\n", credentials: .init(accountID: 7, token: "test-token"))
  }

  @Test func deleteMatchesContract() async throws {
    let client = makeCommunityApi { request in
      #expect(request.url?.path == "/community/42/delete")
      #expect(request.httpMethod == "POST")
      #expect(request.httpBody == nil)
      #expect(request.value(forHTTPHeaderField: "X-Token") == "test-token")
      return (Data(), try makeHTTPResponse(for: request, statusCode: 200))
    }
    try await client.delete(id: 42, credentials: .init(accountID: 7, token: "test-token"))
  }

  private struct EditBody: Decodable {
    struct Field: Decodable { let value: String }
    let text: Field
  }
}

@MainActor
private final class MutationTestState {
  var calls = 0
  var current = true
  var editedText: String?
  var deletedID: Int64?
  var voidCompletion: CheckedContinuation<Void, Never>?
  var pageCompletion: CheckedContinuation<CommunityPage, Never>?
  var started: CheckedContinuation<Void, Never>?
  private var requests = 0

  func incrementCalls() { calls += 1 }
  func recordEditedText(_ text: String) { editedText = text }
  func recordDeletedID(_ id: Int64) { deletedID = id }

  func nextRequest() -> Int {
    requests += 1
    return requests
  }

  func waitForVoidCompletion() async {
    await withCheckedContinuation { continuation in
      voidCompletion = continuation
      started?.resume()
    }
  }

  func waitForPageCompletion() async -> CommunityPage {
    await withCheckedContinuation { continuation in
      pageCompletion = continuation
      started?.resume()
    }
  }
}

private extension CommunityMutationTests {
  private func post(ownerID: Int64 = 7) throws -> CommunityPost {
    .published(.init(
      descriptor: .init(id: 42, accessHash: "post-hash"), text: "**Исходный**",
      owner: .init(id: ownerID, accessHash: "owner-hash", nickname: "Автор"),
      date: Date(timeIntervalSince1970: 1_790_159_400), edited: false
    ))
  }

  private var drafts: CommunityDrafts {
    CommunityDrafts(load: { nil }, save: { _ in Issue.record("Mutation must not write a new-post draft") }, remove: { Issue.record("Mutation must not remove a new-post draft") })
  }

  private func service(
    list: @escaping @Sendable (String?) async throws -> CommunityPage = { _ in .init(data: [], nextId: nil) },
    edit: @escaping @Sendable (Int64, String) async throws -> Void = { _, _ in },
    delete: @escaping @Sendable (Int64) async throws -> Void = { _ in }
  ) -> CommunityService {
    var service = CommunityService()
    service.publish = { _ in throw CommunityError.unavailable }
    service.list = list
    service.edit = edit
    service.delete = delete
    return service
  }

}
