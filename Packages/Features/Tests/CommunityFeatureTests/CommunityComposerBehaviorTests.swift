import CommunityDraftService
@testable import CommunityFeature
import CommunityService
import CustomDump
import Dependencies
import Synchronization
import Testing

@Suite(.serialized) @MainActor struct CommunityComposerBehaviorTests {
  @Test(arguments: [false, true])
  func uncertainPublicationRequiresConfirmationBeforeAnotherRequest(reply: Bool) async {
    let calls = Mutex(0)
    var service = CommunityService()
    service.publish = { _ in calls.withLock { $0 += 1 }; throw CommunityError.outcomeUnknown }
    service.reply = { _, _ in calls.withLock { $0 += 1 }; throw CommunityError.outcomeUnknown }
    let model = makeComposerModel(
      service: service,
      drafts: .init(load: { .init(content: "Draft") }, save: { _ in }, remove: {}),
      replyTo: reply ? .init(id: 1, accessHash: "parent") : nil)
    defer { model.stop() }
    await model.restore()
    await model.publish()
    #expect(model.requiresRetryConfirmation)
    await model.publish()
    expectNoDifference(calls.withLock { $0 }, 1)
    #expect(model.needsRetryConfirmation)
    await model.publish(confirmedRetry: true)
    expectNoDifference(calls.withLock { $0 }, 2)
  }

  @Test(arguments: [false, true])
  func lateContentChangeDuringDiscardCannotResurrectTheDraft(reply: Bool) async {
    await withMainSerialExecutor {
      let removal = SuspendedDraftRemoval()
      let clock = TestClock()
      var saved: [String] = []
      let model = makeComposerModel(
        service: .init(),
        drafts: .init(load: { .init(content: "Draft") }, save: { saved.append($0.content) }, remove: removal.remove),
        replyTo: reply ? .init(id: 1, accessHash: "parent") : nil, clock: clock)
      defer { model.stop() }
      await model.restore()
      let discard = Task { await model.discard() }
      await removal.waitUntilStarted()
      model.editor.loadSource("Late upload completion")
      model.textChanged()
      removal.finish()
      #expect(await discard.value)
      await clock.advance(by: .seconds(1))
      #expect(saved.isEmpty)
      expectNoDifference(model.editor.markdown, "")
    }
  }

  @Test(arguments: [false, true])
  func editorChangesAutosaveWithoutAView(reply: Bool) async {
    await withMainSerialExecutor {
      let clock = TestClock()
      var saved: [String] = []
      let model = makeComposerModel(
        service: .init(), drafts: .init(load: { nil }, save: { saved.append($0.content) }, remove: {}),
        replyTo: reply ? .init(id: 1, accessHash: "parent") : nil, clock: clock)
      defer { model.stop() }
      await model.restore()
      model.editor.loadSource("Automatically saved")
      await clock.advance(by: .seconds(1))
      expectNoDifference(saved, ["Automatically saved"])
    }
  }

  @Test(arguments: [false, true])
  func overlappingRestoresLoadTheDocumentOnce(reply: Bool) async {
    let load = SuspendedDraftLoad()
    let model = makeComposerModel(
      service: .init(), drafts: .init(load: load.load, save: { _ in }, remove: {}),
      replyTo: reply ? .init(id: 1, accessHash: "parent") : nil)
    defer { model.stop() }
    let first = Task { await model.restore() }
    await load.waitUntilStarted()
    var secondStarted = false
    let second = Task { secondStarted = true; await model.restore() }
    while !secondStarted { await Task.yield() }
    expectNoDifference(load.calls, 1)
    load.finish()
    await first.value
    await second.value
    expectNoDifference(model.editor.markdown, "Restored")
    #expect(model.isReady)
  }

  @Test(arguments: [false, true])
  func discardWaitsForAnExplicitFlushBeforeRemovingItsFile(reply: Bool) async {
    let write = SuspendedDraftWrite()
    let model = makeComposerModel(
      service: .init(), drafts: .init(load: { .init(content: "Draft") },
        save: { await write.save($0.content) }, remove: { write.remove() }),
      replyTo: reply ? .init(id: 1, accessHash: "parent") : nil)
    defer { model.stop() }
    await model.restore()
    let flushing = Task { await model.flushDraft() }
    await write.waitUntilStarted()
    var finished = false
    let discarding = Task {
      let result = await model.discard()
      finished = true
      return result
    }
    for _ in 0..<Constants.maximumActorTurns {
      if finished { break }
      await Task.yield()
    }
    #expect(!finished)
    write.finish()
    #expect(await flushing.value)
    #expect(await discarding.value)
    #expect(write.stored == nil)
  }
}

@MainActor private final class SuspendedDraftRemoval {
  private var started = false
  private var waiter: CheckedContinuation<Void, Never>?
  private var completion: CheckedContinuation<Void, Never>?

  func remove() async {
    started = true
    await withCheckedContinuation {
      completion = $0
      waiter?.resume()
      waiter = nil
    }
  }

  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func finish() {
    completion?.resume()
    completion = nil
  }
}

@MainActor private final class SuspendedDraftLoad {
  private(set) var calls = 0
  private var waiter: CheckedContinuation<Void, Never>?
  private var completions: [CheckedContinuation<CommunityDraftSnapshot<String>?, Never>] = []

  func load() async -> CommunityDraftSnapshot<String>? {
    calls += 1
    return await withCheckedContinuation {
      completions.append($0)
      waiter?.resume()
      waiter = nil
    }
  }

  func waitUntilStarted() async {
    if calls > 0 { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func finish() {
    completions.forEach { $0.resume(returning: .init(content: "Restored")) }
    completions.removeAll()
  }
}

@MainActor private final class SuspendedDraftWrite {
  private(set) var stored: String?
  private var waiter: CheckedContinuation<Void, Never>?
  private var completion: CheckedContinuation<Void, Never>?

  func save(_ value: String) async {
    await withCheckedContinuation {
      completion = $0
      waiter?.resume()
      waiter = nil
    }
    stored = value
  }

  func waitUntilStarted() async {
    if completion != nil { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func finish() {
    completion?.resume()
    completion = nil
  }

  func remove() { stored = nil }
}

private enum Constants {
  static let maximumActorTurns = 1000
}
