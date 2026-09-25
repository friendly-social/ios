import CommunityApi
import CommunityDraftService
@testable import CommunityApiLive
@testable import CommunityDraftServiceLive
@testable import CommunityDraftStorageServiceLive
import CommunityFeature
import CommunityService
@testable import CommunityServiceLive
import Foundation
import Testing

@MainActor
struct CommunityPublicationTests {
  private let descriptor = PostDescriptor(id: 42, accessHash: "hash")

  @Test func restoringDraftDoesNotShowSavedNotice() async {
    let draft = MemoryDraft("Existing draft")
    let model = makeComposerModel(service: service { _ in descriptor }, drafts: draft.client)
    await model.restore()
    model.textChanged()
    #expect(model.draftSaved)
    #expect(!model.showsSavedNotice)
    model.stop()
  }

  @Test func autosaveNoticeAppearsThenExpiresAndCanAppearAgain() async throws {
    let draft = MemoryDraft(nil)
    let model = makeComposerModel(service: service { _ in descriptor }, drafts: draft.client)
    await model.restore()
    defer { model.stop() }
    model.editor.loadSource("First draft")
    model.textChanged()
    #expect(!model.showsSavedNotice)
    try await Task.sleep(for: .milliseconds(500))
    #expect(!model.showsSavedNotice)
    try await Task.sleep(for: .seconds(1))
    #expect(model.showsSavedNotice)
    #expect(draft.text == "First draft")
    try await Task.sleep(for: .seconds(2))
    #expect(!model.showsSavedNotice)
    model.editor.loadSource("Second draft")
    model.textChanged()
    #expect(!model.showsSavedNotice)
    try await Task.sleep(for: .milliseconds(1500))
    #expect(model.showsSavedNotice)
    #expect(draft.text == "Second draft")
  }

  @Test func restoresAndPublishesExactMarkdown() async {
    let draft = MemoryDraft("  **Привет**\n\n| A | B |\n| - | - |\n| 1 | 2 |  ")
    let state = PublicationTestState()
    let model = makeComposerModel(service: service { text in
      await state.record(text)
      return descriptor
    }, drafts: draft.client)
    await model.restore()
    let source = model.editor.markdown
    await model.publish()
    #expect(state.submitted == [source])
    #expect(model.published == descriptor)
    #expect(draft.text == nil)
    #expect(!model.canPublish)
  }

  @Test func ambiguousFailureKeepsDraftAndDoesNotRetry() async {
    let draft = MemoryDraft("Текст")
    let state = PublicationTestState()
    let model = makeComposerModel(service: service { _ in
      await state.incrementCalls()
      throw CommunityError.outcomeUnknown
    }, drafts: draft.client)
    await model.restore()
    await model.publish()
    #expect(state.calls == 1)
    #expect(draft.text == "Текст")
    #expect(model.requiresRetryConfirmation)
    #expect(model.published == nil)
    #expect(model.canPublish)
  }

  @Test func duplicateTapAndLateSessionResponseAreIgnored() async {
    let draft = MemoryDraft("Текст")
    let state = PublicationTestState()
    let model = makeComposerModel(service: service { _ in
      await state.incrementCalls()
      return await state.waitForCompletion()
    }, drafts: draft.client, isCurrentSession: { state.current })
    await model.restore()
    let task = Task { await model.publish() }
    await withCheckedContinuation { state.started = $0 }
    await model.publish()
    #expect(state.calls == 1)
    state.current = false
    state.completion?.resume(returning: descriptor)
    await task.value
    #expect(model.published == nil)
    #expect(draft.text == "Текст")
  }

  @Test func cleanupFailureDoesNotTurnSuccessIntoFailure() async {
    let draft = MemoryDraft("Текст")
    draft.failRemove = true
    let model = makeComposerModel(service: service { _ in descriptor }, drafts: draft.client)
    await model.restore()
    await model.publish()
    #expect(model.published == descriptor)
    #expect(model.publicationError == nil)
    #expect(model.draftError != nil)
    #expect(!model.canPublish)
  }

  @Test func emptyAndOversizeCannotPublish() async {
    let state = PublicationTestState()
    let model = makeComposerModel(service: service { _ in
      await state.incrementCalls()
      return descriptor
    }, drafts: MemoryDraft(nil).client)
    await model.restore()
    model.editor.loadSource(" \n ")
    await model.publish()
    model.editor.loadSource(String(repeating: "😀", count: 2049))
    await model.publish()
    #expect(state.calls == 0)
  }

  @Test func flushSavesLatestTextBeforeClose() async {
    let draft = MemoryDraft(nil)
    let model = makeComposerModel(service: service { _ in descriptor }, drafts: draft.client)
    await model.restore()
    model.editor.loadSource("Первый")
    model.textChanged()
    model.editor.loadSource("Последний")
    model.textChanged()
    #expect(await model.flushDraft())
    #expect(draft.text == "Последний")
    #expect(model.draftSaved)
  }

  @Test func publishedPostSurvivesRefreshFailureAndIsNotRestoredAsDraft() async throws {
    let draft = MemoryDraft("Опубликовано")
    var service = self.service { _ in descriptor }
    service.list = { _ in throw CommunityError.unavailable }
    let feed = makeFeedModel(feedPreparation: .fixture, service: service, drafts: draft.client)
    await feed.didPublish(descriptor, text: "Опубликовано", warning: "Не удалось удалить черновик")
    feed.stop()
    await feed.load()
    #expect(feed.posts.map(\.id) == [42])
    #expect(feed.error != nil)
    feed.compose()
    let composer = try #require(feed.composer)
    await composer.restore()
    #expect(composer.editor.markdown.isEmpty)
  }

  @Test func draftFailuresDoNotBlockPublication() async {
    let drafts = CommunityDrafts(
      load: { throw CocoaError(.fileReadUnknown) },
      save: { _ in throw CocoaError(.fileWriteUnknown) },
      remove: {}
    )
    let model = makeComposerModel(service: service { _ in descriptor }, drafts: drafts)
    await model.restore()
    #expect(model.isReady)
    #expect(model.draftError != nil)
    model.editor.loadSource("Новый текст")
    #expect(await model.flushDraft() == false)
    await model.publish()
    #expect(model.published == descriptor)
  }

}

private extension CommunityPublicationTests {
  private func service(_ publish: @escaping @Sendable (String) async throws -> PostDescriptor) -> CommunityService {
    var service = CommunityService()
    service.publish = publish
    service.list = { _ in CommunityPage(data: [], nextId: nil) }
    return service
  }
}

@MainActor
private final class PublicationTestState {
  var submitted: [String] = []
  var calls = 0
  var completion: CheckedContinuation<PostDescriptor, Never>?
  var started: CheckedContinuation<Void, Never>?
  var current = true

  func record(_ text: String) { submitted.append(text) }
  func incrementCalls() { calls += 1 }

  func waitForCompletion() async -> PostDescriptor {
    await withCheckedContinuation { continuation in
      completion = continuation
      started?.resume()
    }
  }
}

@MainActor
private final class MemoryDraft {
  var text: String?
  var failRemove = false
  init(_ text: String?) { self.text = text }
  var client: CommunityDrafts {
    CommunityDrafts(load: { self.text }, save: { self.text = $0 }, remove: {
      if self.failRemove { throw CocoaError(.fileWriteUnknown) }
      self.text = nil
    })
  }
}

struct CommunityLiveTests {
  @Test func decodesPlainAndDeletedPosts() throws {
    let json = #"{"data":[{"id":1,"accessHash":"a","type":"plain","text":"**Текст**","owner":{"id":7,"accessHash":"owner-hash","nickname":"Alex"},"edited":false,"instant":"2026-09-23T12:30:00.123456Z"},{"id":2,"accessHash":"b","type":"deleted","instant":"2026-09-23T12:30:00Z"}],"nextId":"cursor"}"#
    let page = try JSONDecoder().decode(CommunityPageResponse.self, from: Data(json.utf8)).page
    #expect(page.data.map(\.id) == [1, 2])
    #expect(page.data[0].owner?.nickname == "Alex")
    #expect(page.data[1].text == nil)
    #expect(page.nextId == "cursor")
  }

  @Test func requestMatchesBackendContract() async throws {
    let client = makeCommunityApi { request in
      #expect(request.url?.path == "/community")
      #expect(request.httpMethod == "POST")
      #expect(request.value(forHTTPHeaderField: "X-Token") == "test-token")
      #expect(request.value(forHTTPHeaderField: "X-User-Id") == "7")
      let body = try JSONDecoder().decode([String: String].self, from: #require(request.httpBody))
      #expect(body == ["text": "**Привет**"])
      return (Data(#"{"id":42,"accessHash":"hash"}"#.utf8), try makeHTTPResponse(for: request, statusCode: 200))
    }
    let result = try await client.publish("**Привет**", credentials: .init(accountID: 7, token: "test-token"))
    #expect(result == PostDescriptor(id: 42, accessHash: "hash"))
  }

  @Test func listDecodesConcretePlainPostsWithoutType() async throws {
    let client = makeCommunityApi { request in
      #expect(request.url?.path == "/community/list")
      let json = #"{"data":[{"id":1,"accessHash":"a","text":"**Текст**","owner":{"id":7,"accessHash":"owner-hash","nickname":"Alex"},"edited":false,"instant":"2026-09-23T12:30:00.123456Z"}],"nextId":null}"#
      return (Data(json.utf8), try makeHTTPResponse(for: request, statusCode: 200))
    }
    let page = try await client.list(cursor: nil, credentials: .init(accountID: 7, token: "test-token"))
    #expect(page.data.count == 1)
    guard case .published = page.data.first else { Issue.record("Expected a published post"); return }
    #expect(page.data.first?.text == "**Текст**")
    #expect(page.nextId == nil)
  }

  @Test(arguments: [401, 400, 500]) func statusClassification(status: Int) async throws {
    let client = makeCommunityApi { request in
      (Data(), try makeHTTPResponse(for: request, statusCode: status))
    }
    let expected: CommunityError = status == 401 ? .unauthorized : status == 400 ? .rejected(400) : .outcomeUnknown
    await #expect(throws: expected) {
      try await client.publish("Текст", credentials: .init(accountID: 7, token: "test-token"))
    }
  }

  @Test func draftPersistenceIsolationAndLogout() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = CommunityDraftStore(directory: directory)
    try await store.save("**Текст**", accountID: 1, sessionID: "one")
    let reopened = CommunityDraftStore(directory: directory)
    #expect(try await reopened.load(accountID: 1, sessionID: "one") == "**Текст**")
    #expect(try await store.load(accountID: 2, sessionID: "two") == nil)
    #expect(try await store.load(accountID: 1, sessionID: "new-session") == nil)
    try await store.revoke(accountID: 1, sessionID: "one")
    await #expect(throws: CancellationError.self) {
      try await store.save("Поздняя запись", accountID: 1, sessionID: "one")
    }
    #expect(try await reopened.load(accountID: 1, sessionID: "one") == nil)
  }

  @Test func draftStreamDeliversInitialSaveAndRemoval() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = CommunityDraftStore(directory: directory)
    let stream = try await store.updates(accountID: 1, sessionID: "one")
    var iterator = stream.makeAsyncIterator()
    let initial = await iterator.next()
    #expect(initial == .some(nil))
    try await store.save("draft", accountID: 1, sessionID: "one")
    #expect(await iterator.next() == .some("draft"))
    try await store.remove(accountID: 1, sessionID: "one")
    let removed = await iterator.next()
    #expect(removed == .some(nil))
  }
}
