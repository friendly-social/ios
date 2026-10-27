@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import CustomDump
import Synchronization
import Testing

@MainActor
struct CommunityPreparedContentTests {
  @Test func repeatedFeedPreparationReusesTheFullDocument() async throws {
    let calls = Mutex(0)
    var preparation = CommunityFeedPreparationService()
    preparation.prepareDocument = { source in
      calls.withLock { $0 += 1 }
      return await MarkdownDocument.prepare(source: source)
    }
    let post = post()
    let first = try await preparation.prepare([post], reusing: [])
    let second = try await preparation.prepare([post], reusing: first)
    #expect(first[0].content === second[0].content)
    #expect(first[0].content.document != nil)
    expectNoDifference(calls.withLock { $0 }, 1)
  }

  @Test func detailReusesTheDocumentPassedFromTheFeed() async {
    let post = post()
    let row = await CommunityFeedPreparationService.fixture.prepare(post)
    var preparation = CommunityFeedPreparationService()
    preparation.prepareDocument = { _ in
      Issue.record("Detail parsed a post already prepared by the feed")
      return nil
    }
    var service = CommunityService()
    service.markRead = { _ in }
    let details = CommunityPostDetails(post: post, upstream: [], replies: .init(data: [], nextId: nil))
    let model = makeDetailModel(post: post, selectedRow: row, service: service,
      initialDetails: details, preparation: preparation)
    defer { model.stop() }
    await model.load()
    #expect(model.loaded)
    #expect(model.selectedRow?.content === row.content)
  }

  @Test func editingSelectedPostUpdatesItsPreparedMarkdown() async throws {
    let original = post()
    let row = await CommunityFeedPreparationService.fixture.prepare(original)
    var service = CommunityService()
    service.markRead = { _ in }
    service.edit = { _, _ in }
    let details = CommunityPostDetails(post: original, upstream: [], replies: .init(data: [], nextId: nil))
    let model = makeDetailModel(post: original, selectedRow: row, service: service, initialDetails: details)
    defer { model.stop() }
    await model.load()
    model.edit(original)
    let editor = try #require(model.destination?.editor)
    let source = "# Updated\n\nHello **edited world**"
    editor.editor.loadSource(source)
    await editor.saveButtonTapped()
    #expect(editor.isSaved)
    expectNoDifference(model.post.text, source)
    expectNoDifference(model.selectedRow?.post.text, source)
    expectNoDifference(model.selectedRow?.content.source, source)
    let document = try #require(model.selectedRow?.content.document)
    let expected = try MarkdownDocument(source: source)
    expectNoDifference(document.textSegments, expected.textSegments)
  }
}

private extension CommunityPreparedContentTests {
  private func post() -> CommunityPost {
    .awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "fixture"), text: "Hello **world**"))
  }
}
