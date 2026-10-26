@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import Testing

@MainActor
struct CommunityThreadAuditTests {
  @Test func failedOldLoadDoesNotAttachErrorToNewSelection() async {
    let gate = SuspendedThreadOperation<CommunityPostDetails>()
    var service = baseService()
    service.details = { descriptor in
      if descriptor.id == 1 { return try await gate.run() }
      return details(descriptor.id)
    }
    let model = makeDetailModel(post: post(1), service: service)
    defer { model.stop() }
    let old = Task { await model.load() }
    await gate.waitUntilStarted()
    model.select(post(2))
    await model.load()
    await gate.fail()
    await old.value
    #expect(model.post.id == 2 && model.loaded)
    #expect(model.loadError == nil)
  }

  @Test func oldPageCompletionDoesNotFinishNewPageRequest() async {
    let oldPage = SuspendedThreadOperation<CommunityReplyPage>()
    let newPage = SuspendedThreadOperation<CommunityReplyPage>()
    var service = baseService()
    service.details = { details($0.id, next: "next") }
    service.replies = { descriptor, _ in
      try await (descriptor.id == 1 ? oldPage : newPage).run()
    }
    let model = makeDetailModel(post: post(1), service: service)
    defer { model.stop() }
    await model.load()
    let old = Task { await model.loadMore() }
    await oldPage.waitUntilStarted()
    model.select(post(2))
    await model.load()
    let current = Task { await model.loadMore() }
    await newPage.waitUntilStarted()
    await oldPage.fail()
    await old.value
    #expect(model.isLoadingMore)
    #expect(model.pageError == nil)
    await newPage.succeed(.init(data: [.single(post(3))], nextId: nil))
    await current.value
    #expect(model.replies.map(\.id) == [3] && !model.isLoadingMore)
  }

  @Test func refreshingParentInvalidatesRunningPageRequest() async {
    let gate = SuspendedThreadOperation<CommunityReplyPage>()
    var service = baseService()
    service.details = { details($0.id, next: "next") }
    service.replies = { _, _ in try await gate.run() }
    let model = makeDetailModel(post: post(1), service: service)
    defer { model.stop() }
    await model.load()
    let page = Task { await model.loadMore() }
    await gate.waitUntilStarted()
    await model.load()
    #expect(!model.isLoadingMore)
    await gate.fail()
    await page.value
    #expect(model.pageError == nil && model.nextID == "next")
  }

  @Test func refreshingParentClearsPreviousPaginationError() async {
    var service = baseService()
    service.details = { details($0.id, next: "next") }
    service.replies = { _, _ in throw CommunityError.unavailable }
    let model = makeDetailModel(post: post(1), service: service)
    defer { model.stop() }
    await model.load()
    await model.loadMore()
    #expect(model.pageError != nil)
    await model.load()
    #expect(model.pageError == nil && model.nextID == "next")
  }

  @Test func deletionPreparationDoesNotOverwriteNewSelectionAncestors() async {
    let gate = ThreadMutationPreparation()
    var preparation = CommunityFeedPreparationService()
    preparation.prepareExcerpt = { _ in await gate.prepare() }
    var service = baseService()
    service.delete = { _ in }
    service.details = { descriptor in
      .init(post: post(descriptor.id), upstream: [post(1), post(2)],
            replies: .init(data: [], nextId: nil))
    }
    let initial = CommunityPostDetails(post: post(2), upstream: [post(1)],
      replies: .init(data: [.single(post(3))], nextId: nil))
    let model = makeDetailModel(post: post(2), service: service,
      initialDetails: initial, preparation: preparation)
    defer { model.stop() }
    await model.load()
    await gate.suspendNext()
    let deletion = Task { await model.delete(post(3)) }
    await gate.operation.waitUntilStarted()
    model.select(post(4))
    await model.load()
    await gate.operation.succeed(nil)
    await deletion.value
    #expect(model.post.id == 4)
    #expect(model.upstream.map(\.id) == [1, 2])
    #expect(model.ancestorRows.map(\.id) == [1, 2])
  }
}

private actor SuspendedThreadOperation<Value: Sendable> {
  private var completion: CheckedContinuation<Value, any Error>?
  private var started: CheckedContinuation<Void, Never>?

  func run() async throws -> Value {
    try await withCheckedThrowingContinuation {
      completion = $0
      started?.resume()
      started = nil
    }
  }

  func waitUntilStarted() async {
    if completion != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func fail() {
    completion?.resume(throwing: CommunityError.unavailable)
    completion = nil
  }

  func succeed(_ value: Value) {
    completion?.resume(returning: value)
    completion = nil
  }
}

private actor ThreadMutationPreparation {
  let operation = SuspendedThreadOperation<MarkdownExcerpt?>()
  private var suspendsNext = false

  func suspendNext() { suspendsNext = true }

  func prepare() async -> MarkdownExcerpt? {
    guard suspendsNext else { return nil }
    suspendsNext = false
    return try? await operation.run()
  }
}

private func baseService() -> CommunityService {
  var service = CommunityService()
  service.markRead = { _ in }
  return service
}

private func details(_ id: Int64, next: String? = nil) -> CommunityPostDetails {
  .init(post: post(id), upstream: [], replies: .init(data: [], nextId: next))
}

private func post(_ id: Int64) -> CommunityPost {
  .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "hash-\(id)"), text: "Post \(id)"))
}
