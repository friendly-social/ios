import CommunityMarkdownService
import CustomDump
import Foundation
import PostTranslationService
@testable import PostTranslationServiceLive
import Testing

struct PostTranslationServiceTests {
  @Test func nextLanguageCyclesBetweenEnglishAndRussian() {
    expectNoDifference(PostTranslationLanguage.english.next, .russian)
    expectNoDifference(PostTranslationLanguage.russian.next, .english)
  }

  @Test func unavailableDeviceDoesNotOfferTranslation() async throws {
    let service = PostTranslationServiceLive(
      languagesInstalled: { false },
      translateSegments: { segments, _, _ in
        Issue.record("Unavailable translation must not start")
        return segments
      })
    let source = try input("This release improves performance.")
    #expect(await service.load(source) == nil)
    await #expect(throws: PostTranslationError.self) {
      try await service.translate(source, to: .russian)
    }
  }

  @Test func availabilityIsRecheckedForCachedPosts() async throws {
    let availability = LanguageInstallation()
    let service = PostTranslationServiceLive(languagesInstalled: { await availability.isInstalled })
    let source = try input("This release improves performance.")
    #expect(await service.load(source) != nil)
    await availability.setInstalled(false)
    #expect(await service.load(source) == nil)
    await availability.setInstalled(true)
    #expect(await service.load(source) != nil)
  }

  @Test func translationFailureDoesNotPoisonNextRequest() async throws {
    let attempts = TranslationAttempts()
    let service = PostTranslationServiceLive(
      languagesInstalled: { true },
      translateSegments: { segments, _, _ in
        if await attempts.next() == 1 { throw PostTranslationError.failed }
        return segments.map { _ in AttributedString("Перевод готов") }
      })
    let source = try input("This release improves performance.")
    await #expect(throws: PostTranslationError.self) {
      try await service.translate(source, to: .russian)
    }
    let result = try await service.translate(source, to: .russian)
    expectNoDifference(result.selection, .translated(.russian))
    expectNoDifference(result.translations[.russian], [AttributedString("Перевод готов")])
    let count = await attempts.count
    expectNoDifference(count, 2)
  }

  @Test func availabilityCanDisappearBetweenLoadAndTranslation() async throws {
    let availability = LanguageInstallation()
    let service = PostTranslationServiceLive(languagesInstalled: { await availability.isInstalled })
    let source = try input("This release improves performance.")
    #expect(await service.load(source) != nil)
    await availability.setInstalled(false)
    await #expect(throws: PostTranslationError.self) {
      try await service.translate(source, to: .russian)
    }
    await availability.setInstalled(true)
    #expect(await service.load(source) != nil)
  }

  @Test func cancelledTranslationDoesNotCacheLateCompletion() async throws {
    let gate = SuspendedTranslation()
    let service = PostTranslationServiceLive(
      languagesInstalled: { true },
      translateSegments: { segments, _, _ in await gate.wait(); return segments })
    let source = try input("This release improves performance.")
    let operation = Task { try await service.translate(source, to: .russian) }
    await gate.started()
    operation.cancel()
    await gate.resume()
    await #expect(throws: CancellationError.self) { try await operation.value }
    let cached = try #require(await service.load(source))
    #expect(cached.translations.isEmpty)
    expectNoDifference(cached.selection, .original)
  }

  @Test func mixedParagraphsTranslateOnlyForeignProse() throws {
    let text = try text(
      "This release improves performance.\n\nВ этой версии исправлены ошибки и улучшена производительность.")
    expectNoDifference(text.detectedLanguages, [.english, .russian])
    #expect(text.isSupported)
    expectNoDifference(text.indices(to: .russian).map { String(text.segments[$0].characters) },
      ["This release improves performance."])
    expectNoDifference(text.indices(to: .english).map { String(text.segments[$0].characters) },
      ["В этой версии исправлены ошибки и улучшена производительность."])
  }

  @Test func languageChangesAcrossLinesWithoutSentencePunctuation() throws {
    let text = try text(
      "This release improves performance\nВ этой версии исправлены ошибки и улучшена производительность")
    expectNoDifference(text.detectedLanguages, [.english, .russian])
    expectNoDifference(text.indices(to: .russian).map { String(text.segments[$0].characters) },
      ["This release improves performance\nВ этой версии исправлены ошибки и улучшена производительность"])
  }

  @Test func mixedSentencesTranslateTogetherForContext() throws {
    let text = try text(
      "Пофиксил **memory leak** в приложении. The next release is ready to download.")
    expectNoDifference(text.detectedLanguages, [.english, .russian])
    let context = "Пофиксил memory leak в приложении. The next release is ready to download."
    expectNoDifference(text.indices(to: .russian).map { String(text.segments[$0].characters) }, [context])
    expectNoDifference(text.indices(to: .english).map { String(text.segments[$0].characters) }, [context])
  }

  @Test func repeatedTextKeepsWholeSentenceContext() throws {
    let text = try text(
      "This **release** improves performance. Этот **release** исправляет ошибки в приложении.")
    expectNoDifference(text.indices(to: .russian).map { String(text.segments[$0].characters) },
      ["This release improves performance. Этот release исправляет ошибки в приложении."])
  }

  @Test func codeImageCaptionsAndURLsDoNotDetermineProseLanguage() throws {
    let text = try text(
      "В этой версии исправлены ошибки `this is a very long English code sample` в приложении. "
      + "![This caption should never determine the language](https://example.com/a.png)")
    expectNoDifference(text.detectedLanguages, [.russian])
    #expect(text.indices(to: .russian).isEmpty)
  }

  @Test func unknownLanguageHasNoTranslationAction() async throws {
    let service = PostTranslationServiceLive()
    #expect(await service.load(try input("OK")) == nil)
  }

  @Test(arguments: [
    "On frappe à ma porte. Qui est là ?",
    "Dieses Update verbessert die Leistung und behebt einige Fehler.",
    "В этой версии исправлены ошибки.\n\nOn frappe à ma porte. Qui est là ?",
  ])
  func otherLanguagesHaveNoTranslationAction(source: String) async throws {
    let service = PostTranslationServiceLive()
    #expect(await service.load(try input(source)) == nil)
    await #expect(throws: PostTranslationError.self) {
      try await service.translate(try input(source), to: .english)
    }
  }

  @Test func codeImagesAndURLsHaveNoTranslationAction() throws {
    let text = try text(
      "`Hello world`\n\n![English caption](https://example.com/a.png)\n\nhttps://example.com/this-release-improves-performance")
    #expect(text.detectedLanguages.isEmpty)
    #expect(!text.isSupported)
  }

  @Test func sameLanguageKeepsExactOriginalAndRestoresSelection() async throws {
    let service = PostTranslationServiceLive(languagesInstalled: { true })
    let source = "В этой версии **исправлены ошибки** и улучшена производительность."
    let translated = try await service.translate(try input(source), to: .russian)
    expectNoDifference(translated.translations[.russian], try input(source).segments)
    expectNoDifference(translated.selection, .translated(.russian))
    await service.selectVersion(.original, for: source)
    let restored = try #require(await service.load(try input(source)))
    expectNoDifference(restored.selection, .original)
    expectNoDifference(restored.translations[.russian], try input(source).segments)
  }
}

private actor LanguageInstallation {
  private(set) var isInstalled = true
  func setInstalled(_ value: Bool) { isInstalled = value }
}

private actor TranslationAttempts {
  private(set) var count = 0
  func next() -> Int { count += 1; return count }
}

private actor SuspendedTranslation {
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

private extension PostTranslationServiceTests {
  private func input(_ source: String) throws -> PostTranslationInput {
    PostTranslationInput(source: source, segments: try MarkdownDocument(source: source).textSegments)
  }

  private func text(_ source: String) throws -> PostTranslationText {
    PostTranslationText(segments: try input(source).segments)
  }
}
