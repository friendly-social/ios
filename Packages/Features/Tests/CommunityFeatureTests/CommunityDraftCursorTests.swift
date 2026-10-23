import CommunityDraftService
@testable import CommunityDraftServiceLive
@testable import CommunityEditorFeature
@testable import CommunityFeature
import CommunityService
import CustomDump
import Dependencies
import Foundation
import Testing

@Suite(.serialized) @MainActor struct CommunityDraftCursorTests {
  @Test func composerRestoresAndSavesCursorWithoutChangingMarkdown() async throws {
    let source = "Hello **world**"
    var saved: (String, Int?)?
    var loads = 0
    let drafts = CommunityDrafts(
      load: { loads += 1; return .init(content: source, cursor: 8) },
      save: { saved = ($0.content, $0.cursor) }, remove: {})
    let model = makeComposerModel(service: CommunityService(), drafts: drafts)
    defer { model.stop() }
    await model.restore()
    expectNoDifference(model.editor.selection, NSRange(location: 8, length: 0))
    model.editor.setSelection(NSRange(location: 4, length: 0))
    #expect(await model.flushDraft())
    expectNoDifference(saved?.0, source)
    expectNoDifference(saved?.1, 4)
    expectNoDifference(loads, 1)
  }

  @Test func cursorMovementAutosavesWithoutShowingContentSavedNotice() async throws {
    await withMainSerialExecutor {
      let clock = TestClock()
      var saved: Int?
      let drafts = CommunityDrafts(
        load: { .init(content: "Hello world", cursor: 8) }, save: { saved = $0.cursor }, remove: {})
      let model = makeComposerModel(service: CommunityService(), drafts: drafts, clock: clock)
      defer { model.stop() }
      await model.restore()
      model.editor.setSelection(NSRange(location: 4, length: 0))
      model.textChanged()
      await clock.advance(by: .seconds(1))
      expectNoDifference(saved, 4)
      #expect(model.draftSaved)
      #expect(!model.showsSavedNotice)
    }
  }

  @Test(arguments: [false, true])
  func markdownEditFallsBackToEndAfterReopening(isReply: Bool) async throws {
    var stored = CommunityDraftSnapshot(content: "Original draft", cursor: 8)
    let drafts = CommunityDrafts(load: { stored }, save: { stored = $0 }, remove: {})
    let target = isReply ? PostDescriptor(id: 42, accessHash: "reply") : nil
    let model = makeComposerModel(service: CommunityService(), drafts: drafts, replyTo: target)
    defer { model.stop() }
    await model.restore()
    model.editor.loadSource("Edited **draft** in Markdown")
    #expect(await model.flushDraft())
    let reopened = makeComposerModel(service: CommunityService(), drafts: drafts, replyTo: target)
    defer { reopened.stop() }
    await reopened.restore()
    expectNoDifference(reopened.editor.markdown, "Edited **draft** in Markdown")
    expectNoDifference(reopened.editor.selection,
      NSRange(location: reopened.editor.text.length, length: 0))
  }

  @Test func missingCursorOpensAtEnd() async {
    let source = "Old draft"
    let drafts = CommunityDrafts(
      load: { .init(content: source) }, save: { _ in }, remove: {})
    let model = makeComposerModel(service: CommunityService(), drafts: drafts)
    defer { model.stop() }
    await model.restore()
    expectNoDifference(model.editor.selection, NSRange(location: source.utf16.count, length: 0))
    #expect(model.draftError == nil)
    #expect(model.canPublish)
  }

  @Test func cursorSurvivesReopenAndOlderDecodersReadTheSameContent() async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = "**Hi** 👩🏽‍💻\n\n![](https://example.com/photo.jpg)"
    let store = CommunityDraftStore(directory: directory)
    try await store.save(.init(content: source, cursor: 8), accountID: 1, sessionID: "one")
    let reopened = CommunityDraftStore(directory: directory)
    let restoredMarkdown = try await reopened.load(accountID: 1, sessionID: "one")
    expectNoDifference(restoredMarkdown?.content, source)
    expectNoDifference(restoredMarkdown?.cursor, 8)
    let data = try Data(contentsOf: directory.appending(component: "1-new-post.json"))
    let legacy = try JSONDecoder().decode(LegacyDraft.self, from: data)
    expectNoDifference(legacy.version, 1)
    expectNoDifference(legacy.markdown, source)
  }

  @Test(arguments: [nil, "broken"] as [String?])
  func missingOrDamagedCursorDoesNotDiscardAnExistingDraft(cursor: String?) async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var json: [String: Any] = ["version": 1, "sessionID": "one", "markdown": "Old draft"]
    if let cursor { json["cursor"] = cursor }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: json).write(to: directory.appending(component: "1-new-post.json"))
    let store = CommunityDraftStore(directory: directory)
    let restoredMarkdown = try await store.load(accountID: 1, sessionID: "one")
    expectNoDifference(restoredMarkdown?.content, "Old draft")
    expectNoDifference(restoredMarkdown?.cursor, nil)
    let drafts = CommunityDrafts(load: { restoredMarkdown }, save: { _ in }, remove: {})
    let model = makeComposerModel(service: CommunityService(), drafts: drafts)
    defer { model.stop() }
    await model.restore()
    expectNoDifference(model.editor.selection, NSRange(location: "Old draft".utf16.count, length: 0))
    #expect(model.draftError == nil)
  }

  @Test func cursorAndContentStayTogetherAndSessionRemainsIsolated() async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = CommunityDraftStore(directory: directory)
    try await store.save(.init(content: "Draft", cursor: 3), accountID: 1, sessionID: "one")
    let restored = try await store.load(accountID: 1, sessionID: "one")
    expectNoDifference(restored, .init(content: "Draft", cursor: 3))
    let differentSession = try await store.load(accountID: 1, sessionID: "other")
    expectNoDifference(differentSession, nil)
    try await store.save(.init(content: "Legacy resave"), accountID: 1, sessionID: "one")
    let resaved = try await store.load(accountID: 1, sessionID: "one")
    expectNoDifference(resaved, .init(content: "Legacy resave"))
  }

  @Test(arguments: [(-1, 9), (3, 9), (Int.max, 9), (nil, 9), (8, 8)] as [(Int?, Int)])
  func restoredCursorHasSafeUTF16AndGraphemeBoundaries(input: Int?, expected: Int) {
    let editor = CommunityEditorViewModel(source: "A👩🏽‍💻B")
    editor.loadSource(editor.markdown)
    editor.restoreCursor(input)
    expectNoDifference(editor.selection, NSRange(location: expected, length: 0))
  }

  @Test func consolidatedServiceKeepsReplyPathsAndLegacyNormalization() async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let parent = PostDescriptor(id: 42, accessHash: "reply")
    let live = CommunityDraftServiceLive(directory: directory)
    let composer = live.replyDrafts(parent, 1, "one", { true })
    try await composer.save(.init(content: "Hello", cursor: 3))
    let reopened = CommunityDraftServiceLive(directory: directory)
    let restored = try await reopened.replyDrafts(parent, 1, "one", { true }).load()
    expectNoDifference(restored?.content, "Hello")
    expectNoDifference(restored?.cursor, 3)
    let file = directory.appending(path: "Replies/42/1-new-post.json")
    let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    expectNoDifference(json["version"] as? Int, 1)
    let differentSession = try await reopened.replyDrafts(parent, 1, "other", { true }).load()
    expectNoDifference(differentSession, nil)
  }

  @Test func consolidatedServiceRevokesSharedPostStoreAndKeepsNewSession() async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = CommunityDraftServiceLive(directory: directory)
    let previous = live.postDrafts(1, "one", { true })
    try await previous.save(.init(content: "Previous", cursor: 3))
    try await live.revokePostDrafts(1, "one")
    await #expect(throws: CancellationError.self) {
      try await previous.save(.init(content: "Late write"))
    }
    let current = live.postDrafts(1, "two", { true })
    try await current.save(.init(content: "Current", cursor: 4))
    try await previous.remove()
    let restored = try await current.load()
    expectNoDifference(restored, .init(content: "Current", cursor: 4))
  }

  @Test func consolidatedDraftStreamFiltersEmptySourceAndPreservesStoredMarkdown() async throws {
    let directory = directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = CommunityDraftServiceLive(directory: directory)
    let drafts = live.postDrafts(1, "one", { true })
    try await drafts.save(.init(content: " \n ", cursor: 1))
    let stream = try await live.postDraftUpdates(1, "one")
    var iterator = stream.makeAsyncIterator()
    let initial = await iterator.next()
    expectNoDifference(initial, .some(nil))
    let source = " **Hello** \n"
    try await drafts.save(.init(content: source, cursor: 3))
    let update = await iterator.next()
    expectNoDifference(update, .some(source))
    let stored = try await drafts.load()
    expectNoDifference(stored, .init(content: source, cursor: 3))
    try await drafts.save(.init(content: " \n "))
    let empty = await iterator.next()
    expectNoDifference(empty, .some(nil))
  }
}

private extension CommunityDraftCursorTests {
  private func directory() -> URL {
    FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
  }
}

private struct LegacyDraft: Decodable {
  let version: Int
  let sessionID: String
  let markdown: String
}
