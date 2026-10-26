@testable import CommunityFeature
import CommunityMarkdownService
import CustomDump
import Dependencies
import Foundation
import PostTranslationService
import Testing

@MainActor
struct CommunityPostTranslationTests {
  @Test func stalledTranslationTimesOutAndRejectsLateResult() async throws {
    try await withMainSerialExecutor {
      let gate = TranslationGate()
      let clock = TestClock()
      let model = makeModel(service: translationService(
        load: { _ in .init(detectedLanguages: [.english]) },
        translate: { _, language in
          await gate.wait()
          return .init(detectedLanguages: [.english], translations: [language: translationSegments("Поздний ответ")],
            selection: .translated(language))
        }), clock: clock)
      await model.load(content("Hello world"))
      await model.cycleLanguage()
      let id = try #require(model.requestID)
      let operation = Task { await model.translateRequested(id) }
      await gate.started()
      let timeout = Task { await model.waitForTranslation(id) }
      await clock.advance(by: .seconds(30))
      await timeout.value
      #expect(model.requestID == nil)
      #expect(model.languageLabel == nil)
      await gate.resume()
      await operation.value
      expectNoDifference(model.content?.document?.textSegments, translationSegments("Hello world"))
    }
  }

  @Test func previousTimeoutDoesNotCancelAnotherRequest() async throws {
    try await withMainSerialExecutor {
      let clock = TestClock()
      let model = makeModel(service: translationService(load: { _ in .init(detectedLanguages: [.english]) }), clock: clock)
      await model.load(content("Hello world"))
      await model.cycleLanguage()
      let previous = try #require(model.requestID)
      let timeout = Task { await model.waitForTranslation(previous) }
      await clock.advance(by: .seconds(10))
      await model.load(content("Edited post"))
      await model.cycleLanguage()
      let current = try #require(model.requestID)
      await clock.advance(by: .seconds(20))
      await timeout.value
      expectNoDifference(model.requestID, current)
      expectNoDifference(model.languageLabel, "EN")
      model.stop()
    }
  }

  @Test func failedTranslationHidesActionAndStopsLoading() async throws {
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { _, _ in throw PostTranslationError.failed }))
    await model.load(content("Hello world"))
    await model.cycleLanguage()
    await model.translateRequested(try #require(model.requestID))
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Hello world"))
    #expect(model.requestID == nil)
    #expect(model.languageLabel == nil)
  }

  @Test func unavailableAfterReloadHidesTranslationAction() async {
    let availability = TranslationAvailability()
    let model = makeModel(service: translationService(load: { _ in
      await availability.isAvailable ? .init(detectedLanguages: [.english]) : nil
    }))
    let original = content("Hello world")
    await model.load(original)
    expectNoDifference(model.languageLabel, "EN")
    await availability.disable()
    await model.load(original)
    #expect(model.languageLabel == nil)
    #expect(model.requestID == nil)
  }

  @Test func firstTapTranslatesAndReusesCachedContent() async throws {
    let calls = TranslationCalls()
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { source, language in
        await calls.record(source.source)
        return .init(detectedLanguages: [.english], translations: [language: translationSegments("**Привет мир**")], selection: .translated(language))
      }, selectVersion: { _, _ in }))
    await model.load(content("**Hello world**"))
    await model.cycleLanguage()
    let id = try #require(model.requestID)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Hello world**"))
    let initialCalls = await calls.count
    expectNoDifference(initialCalls, 0)
    await model.translateRequested(id)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Привет мир**"))
    expectNoDifference(model.targetLanguage, .russian)
    #expect(model.isTranslated)
    #expect(model.content?.excerpt != nil)
    await model.showOriginal()
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Hello world**"))
    await model.cycleLanguage()
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Привет мир**"))
    let finalCalls = await calls.count
    expectNoDifference(finalCalls, 1)
  }

  @Test func failedRequestCanRecoverWithoutRestarting() async throws {
    let calls = TranslationCalls()
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { input, language in
        await calls.record(input.source)
        if await calls.count == 1 { throw PostTranslationError.failed }
        return .init(detectedLanguages: [.english], translations: [language: translationSegments("Привет мир")],
          selection: .translated(language))
      }))
    let original = content("Hello world")
    await model.load(original)
    await model.cycleLanguage()
    let first = try #require(model.requestID)
    await model.translateRequested(first)
    #expect(model.languageLabel == nil)
    await model.load(original)
    await model.cycleLanguage()
    let retry = try #require(model.requestID)
    #expect(retry != first)
    await model.translateRequested(retry)
    expectNoDifference(model.languageLabel, "RU")
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Привет мир"))
    #expect(model.requestID == nil)
  }

  @Test func restoresSelectedTranslationOnAnotherScreen() async {
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [.english], translations: [.russian: translationSegments("Привет мир")], selection: .translated(.russian))
    }))
    await model.load(content("Hello world"))
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Привет мир"))
    #expect(model.isTranslated)
    #expect(model.requestID == nil)
  }

  @Test func editedPostRejectsPreviousTranslationCompletion() async throws {
    let gate = TranslationGate()
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { _, language in
        await gate.wait()
        return .init(detectedLanguages: [.english], translations: [language: translationSegments("Старый текст")], selection: .translated(language))
      }))
    await model.load(content("Original post"))
    await model.cycleLanguage()
    let id = try #require(model.requestID)
    let task = Task { await model.translateRequested(id) }
    await gate.started()
    await model.load(content("Edited post"))
    await gate.resume()
    await task.value
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Edited post"))
    #expect(!model.isTranslated)
    #expect(model.requestID == nil)
  }

  @Test func cancellationKeepsOriginalWithoutError() async throws {
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { _, _ in throw CancellationError() }))
    await model.load(content("Hello world"))
    await model.cycleLanguage()
    await model.translateRequested(try #require(model.requestID))
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Hello world"))
    #expect(model.requestID == nil)
  }

  @Test func mixedPostStartsWithOriginalWithoutAutomaticTranslation() async {
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [.english, .russian])
    }))
    let source = "Hello world. Привет, мир."
    await model.load(content(source))
    expectNoDifference(model.languageLabel, "EN/RU")
    expectNoDifference(model.nextSelection, .translated(.english))
    expectNoDifference(model.content?.document?.textSegments, translationSegments(source))
    #expect(model.requestID == nil)
  }

  @Test(arguments: [PostTranslationLanguage.english, .russian])
  func quickActionCyclesDisplayedLanguageAndRestoresExactOriginal(
    sourceLanguage: PostTranslationLanguage
  ) async {
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [sourceLanguage], translations: [sourceLanguage.next: translationSegments("Translated version")])
    }))
    await model.load(content("**Exact original**"))
    expectNoDifference(model.languageLabel, sourceLanguage.rawValue.uppercased())
    await model.cycleLanguage()
    expectNoDifference(model.languageLabel, sourceLanguage.next.rawValue.uppercased())
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Translated version"))
    await model.cycleLanguage()
    expectNoDifference(model.languageLabel, sourceLanguage.rawValue.uppercased())
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Exact original**"))
    expectNoDifference(model.translation?.selection, .original)
    #expect(model.requestID == nil)
  }

  @Test(arguments: [PostTranslationLanguage.english, .russian])
  func choosingOriginalLanguageInMenuRestoresOriginal(sourceLanguage: PostTranslationLanguage) async {
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [sourceLanguage], translations: [sourceLanguage.next: translationSegments("Translated version")],
        selection: .translated(sourceLanguage.next))
    }))
    await model.load(content("**Exact original**"))
    await model.translate(to: sourceLanguage)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("**Exact original**"))
    expectNoDifference(model.translation?.selection, .original)
    #expect(model.requestID == nil)
  }

  @Test func mixedPostCyclesEnglishRussianAndExactOriginalRepeatedly() async {
    let source = "Hello **world**. Привет **мир**."
    let english = "Hello **world**. Hello **world**."
    let russian = "Привет **мир**. Привет **мир**."
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [.english, .russian], translations: [.english: translationSegments(english), .russian: translationSegments(russian)])
    }))
    await model.load(content(source))
    for _ in 0..<2 {
      expectNoDifference(model.languageLabel, "EN/RU")
      await model.cycleLanguage()
      expectNoDifference(model.languageLabel, "EN")
      expectNoDifference(model.content?.document?.textSegments, translationSegments(english))
      await model.cycleLanguage()
      expectNoDifference(model.languageLabel, "RU")
      expectNoDifference(model.content?.document?.textSegments, translationSegments(russian))
      await model.cycleLanguage()
      expectNoDifference(model.languageLabel, "EN/RU")
      expectNoDifference(model.content?.document?.textSegments, translationSegments(source))
      expectNoDifference(model.translation?.selection, .original)
      #expect(model.requestID == nil)
    }
  }

  @Test func uncertainLanguageHasNoTranslationAction() async {
    let model = makeModel(service: translationService(load: { _ in .init(detectedLanguages: []) }))
    await model.load(content("OK"))
    #expect(model.translation == nil)
    #expect(model.languageLabel == nil)
    await model.translate(to: .english)
    #expect(model.requestID == nil)
  }

  @Test func switchesBetweenBothCachedLanguagesAndExactOriginal() async {
    let source = "Hello **world**. Привет **мир**."
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [.english, .russian],
        translations: [.english: translationSegments("Hello **world**. Hello **world**."), .russian: translationSegments("Привет **мир**. Привет **мир**.")])
    }))
    await model.load(content(source))
    await model.translate(to: .russian)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Привет **мир**. Привет **мир**."))
    await model.translate(to: .english)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Hello **world**. Hello **world**."))
    await model.showOriginal()
    expectNoDifference(model.content?.document?.textSegments, translationSegments(source))
    expectNoDifference(model.targetLanguage, .english)
    await model.translate(to: .english)
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Hello **world**. Hello **world**."))
    #expect(model.requestID == nil)
  }

  @Test func failedLanguageChangeKeepsDisplayedTextAndHidesAction() async throws {
    let model = makeModel(service: translationService(load: { _ in
      .init(detectedLanguages: [.english, .russian], translations: [.russian: translationSegments("Русский текст")],
        selection: .translated(.russian))
    }))
    await model.load(content("Mixed text. Смешанный текст."))
    await model.translate(to: .english)
    expectNoDifference(model.languageLabel, "RU")
    await model.translateRequested(try #require(model.requestID))
    expectNoDifference(model.content?.document?.textSegments, translationSegments("Русский текст"))
    #expect(model.languageLabel == nil)
  }

  @Test func nonTextOrDeletedPostsHaveNoTranslationAction() async {
    let model = makeModel(service: translationService(load: { _ in nil }))
    await model.load(content("👋"))
    #expect(model.translation == nil)
    await model.cycleLanguage()
    #expect(model.requestID == nil)
    await model.load(.init(source: nil, document: nil))
    #expect(model.translation == nil)
  }

  @Test func translationReceivesFullPreparedContentBeyondTheExcerpt() async throws {
    let source = String(repeating: "Hello world. ", count: 80) + "\n\n![cat](https://example.com/cat.png)\n\nFull tail"
    let original = content(source)
    let segments = try #require(original.document?.textSegments)
    #expect(original.excerpt?.isTruncated == true)
    let model = makeModel(service: translationService(
      load: { _ in .init(detectedLanguages: [.english]) },
      translate: { input, language in
        expectNoDifference(input.segments, segments)
        return .init(detectedLanguages: [.english], translations: [language: segments], selection: .translated(language))
      }))
    await model.load(original)
    await model.cycleLanguage()
    await model.translateRequested(try #require(model.requestID))
    expectNoDifference(model.content?.document?.blocks.count, 3)
    expectNoDifference(model.content?.document?.textSegments, segments)
    await model.showOriginal()
    #expect(model.content === original)
  }
}

private extension CommunityPostTranslationTests {
  private func translationService(
    load: @escaping @Sendable (PostTranslationInput) async -> PostTranslation?,
    translate: @escaping @Sendable (PostTranslationInput, PostTranslationLanguage) async throws -> PostTranslation = { _, _ in
      throw PostTranslationError.unavailable
    },
    selectVersion: @escaping @Sendable (String, PostTranslationSelection) async -> Void = { _, _ in }
  ) -> PostTranslationService {
    PostTranslationService(load: load, translate: translate, selectVersion: selectVersion)
  }

  private func makeModel(
    service: PostTranslationService, clock: any Clock<Duration> = TestClock()
  ) -> CommunityPostTranslationViewModel {
    withDependencies {
      $0.uuid = .incrementing
      $0.continuousClock = clock
      $0[PostTranslationService.self] = service
      $0[CommunityFeedPreparationService.self] = .fixture
    } operation: {
      CommunityPostTranslationViewModel()
    }
  }

  private func content(_ source: String) -> CommunityFeedPost.Content {
    .init(source: source, document: try? MarkdownDocument(source: source))
  }
}

private actor TranslationCalls {
  private(set) var count = 0
  func record(_ source: String) { count += 1 }
}

private actor TranslationAvailability {
  private(set) var isAvailable = true
  func disable() { isAvailable = false }
}

private actor TranslationGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var startWaiter: CheckedContinuation<Void, Never>?

  func wait() async {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      startWaiter?.resume()
      startWaiter = nil
    }
  }

  func started() async {
    if continuation != nil { return }
    await withCheckedContinuation { startWaiter = $0 }
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private func translationSegments(_ source: String) -> [AttributedString] {
  (try? MarkdownDocument(source: source).textSegments) ?? []
}
