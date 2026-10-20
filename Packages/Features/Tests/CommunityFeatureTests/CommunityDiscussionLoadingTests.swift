@testable import CommunityFeature
import CommunityMarkdownService
import CommunityService
import CustomDump
import Testing

@MainActor struct CommunityDiscussionLoadingTests {
  @Test(arguments: [false, true])
  func initialLoadKeepsRepliesHiddenUntilPreparationCompletes(cancelled: Bool) async {
    let gate = DiscussionPreparationGate()
    await gate.suspendNext()
    let details = details(replyID: 2, nextID: "next")
    let model = model(details: details, gate: gate)
    defer { model.stop() }
    let loading = Task { await model.load() }
    await gate.waitUntilSuspended()
    #expect(model.isLoading && !model.loaded)
    #expect(model.replies.isEmpty && model.replyRows.isEmpty)
    #expect(model.nextID == nil)
    if cancelled { loading.cancel() }
    await gate.resume()
    await loading.value
    #expect(!model.isLoading)
    expectNoDifference(model.loaded, !cancelled)
    expectNoDifference(model.replies.map(\.id), cancelled ? [] : [2])
    expectNoDifference(model.replyRows.map(\.id), cancelled ? [] : [2])
    expectNoDifference(model.nextID, cancelled ? nil : "next")
  }

  @Test func refreshKeepsPreviousContentUntilReplacementIsReady() async {
    let gate = DiscussionPreparationGate()
    let initial = details(replyID: 2, nextID: "old")
    let updated = details(replyID: 3, nextID: "new")
    let model = model(details: updated, initial: initial, gate: gate)
    defer { model.stop() }
    await model.load()
    await gate.suspendNext()
    let loading = Task { await model.load() }
    await gate.waitUntilSuspended()
    #expect(model.isLoading && model.loaded)
    expectNoDifference(model.replies.map(\.id), [2])
    expectNoDifference(model.replyRows.map(\.id), [2])
    expectNoDifference(model.nextID, "old")
    await gate.resume()
    await loading.value
    #expect(!model.isLoading && model.loaded)
    expectNoDifference(model.replies.map(\.id), [3])
    expectNoDifference(model.replyRows.map(\.id), [3])
    expectNoDifference(model.nextID, "new")
  }
}

private extension CommunityDiscussionLoadingTests {
  private func model(
    details: CommunityPostDetails, initial: CommunityPostDetails? = nil, gate: DiscussionPreparationGate
  ) -> CommunityPostDetailViewModel {
    var service = CommunityService()
    service.details = { _ in details }
    var preparation = CommunityFeedPreparationService()
    preparation.prepareExcerpt = { _ in await gate.prepare() }
    return makeDetailModel(post: details.post, service: service, initialDetails: initial, preparation: preparation)
  }

  private func details(replyID: Int64, nextID: String) -> CommunityPostDetails {
    .init(post: post(1), upstream: [], replies: .init(data: [.single(post(replyID))], nextId: nextID))
  }

  private func post(_ id: Int64) -> CommunityPost {
    .awaitingDetails(.init(descriptor: .init(id: id, accessHash: "fixture"), text: "Post \(id)"))
  }
}

private actor DiscussionPreparationGate {
  private var suspendsNext = false
  private var completion: CheckedContinuation<MarkdownExcerpt?, Never>?
  private var waiter: CheckedContinuation<Void, Never>?

  func suspendNext() { suspendsNext = true }

  func prepare() async -> MarkdownExcerpt? {
    guard suspendsNext else { return nil }
    suspendsNext = false
    return await withCheckedContinuation {
      completion = $0
      waiter?.resume()
      waiter = nil
    }
  }

  func waitUntilSuspended() async {
    if completion != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func resume() {
    completion?.resume(returning: nil)
    completion = nil
  }
}
