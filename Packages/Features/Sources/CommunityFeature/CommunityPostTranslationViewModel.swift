import CommunityMarkdownService
import Dependencies
import Foundation
import Observation
import PostTranslationService

@MainActor @Observable
final class CommunityPostTranslationViewModel {
  private(set) var translation: PostTranslation?
  private(set) var content: CommunityFeedPost.Content?
  private(set) var requestID: UUID?
  private(set) var targetLanguage = PostTranslationLanguage.english
  @ObservationIgnored @Dependency(PostTranslationService.self) private var service
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Dependency(\.continuousClock) private var clock
  private var original: CommunityFeedPost.Content?
  private var input: PostTranslationInput?
  private var preparedVersions: [PostTranslationLanguage: CommunityFeedPost.Content] = [:]
  private var generation = 0
  private var isAvailable = false

  var isTranslated: Bool {
    if case .translated = translation?.selection { return true }
    return false
  }

  var languageLabel: String? {
    guard isAvailable else { return nil }
    if let displayedLanguage { return displayedLanguage.rawValue.uppercased() }
    return translation?.detectedLanguages.isEmpty == false ? "EN/RU" : nil
  }

  var nextSelection: PostTranslationSelection {
    if let originalLanguage, let displayedLanguage {
      let nextLanguage = displayedLanguage.next
      return nextLanguage == originalLanguage ? .original : .translated(nextLanguage)
    }
    switch translation?.selection ?? .original {
    case .original: return .translated(.english)
    case .translated(.english): return .translated(.russian)
    case .translated(.russian): return .original
    }
  }

  func load(_ original: CommunityFeedPost.Content) async {
    generation += 1
    let request = generation
    resetContentIfNeeded(original)
    requestID = nil
    isAvailable = false
    guard let source = original.source, let document = original.document else { return }
    let input = PostTranslationInput(source: source, segments: document.textSegments)
    self.input = input
    guard let entry = await service.load(input),
          !entry.detectedLanguages.isEmpty else { return }
    guard generation == request, !Task.isCancelled else { return }
    apply(entry, content: selectedContent(entry))
    isAvailable = true
  }

  func cycleLanguage() async {
    switch nextSelection {
    case .original:
      await showOriginal()
    case let .translated(language):
      await translate(to: language)
    }
  }

  func translate(to language: PostTranslationLanguage) async {
    guard isAvailable, requestID == nil, let translation else { return }
    if language == originalLanguage {
      await showOriginal()
      return
    }
    generation += 1
    targetLanguage = language
    if translation.translations[language] != nil {
      await selectVersion(.translated(language))
    } else {
      requestID = uuid()
    }
  }

  func showOriginal() async {
    guard requestID == nil, translation != nil else { return }
    generation += 1
    await selectVersion(.original)
  }

  func translateRequested(_ id: UUID) async {
    guard requestID == id, let input else { return }
    let request = generation
    do {
      let entry = try await service.translate(input, targetLanguage)
      let prepared = selectedContent(entry)
      try Task.checkCancellation()
      guard generation == request, requestID == id else { return }
      apply(entry, content: prepared)
      requestID = nil
    } catch is CancellationError {
      if requestID == id { requestID = nil }
    } catch {
      translationFailed(id)
    }
  }

  func translationFailed(_ id: UUID) {
    guard requestID == id else { return }
    requestID = nil
    isAvailable = false
  }

  func waitForTranslation(_ id: UUID) async {
    do { try await clock.sleep(for: Constants.translationTimeout) }
    catch { return }
    translationFailed(id)
  }

  func stop() {
    generation += 1
    requestID = nil
  }
}

private extension CommunityPostTranslationViewModel {
  private var originalLanguage: PostTranslationLanguage? {
    guard let languages = translation?.detectedLanguages, languages.count == 1 else { return nil }
    return languages.first
  }

  private var displayedLanguage: PostTranslationLanguage? {
    if case let .translated(language) = translation?.selection { return language }
    return originalLanguage
  }

  private func resetContentIfNeeded(_ original: CommunityFeedPost.Content) {
    if self.original?.source != original.source || translation == nil {
      content = original
      translation = nil
      preparedVersions = [:]
      input = nil
    }
    self.original = original
    if !isTranslated { content = original }
  }

  private func selectedContent(_ entry: PostTranslation) -> CommunityFeedPost.Content? {
    guard case let .translated(language) = entry.selection,
          let text = entry.translations[language], let original else { return nil }
    if let cached = preparedVersions[language] { return cached }
    guard let document = try? original.document?.replacingTextSegments(with: text) else { return nil }
    return CommunityFeedPost.Content(source: original.source, document: document)
  }

  private func apply(_ entry: PostTranslation, content prepared: CommunityFeedPost.Content?) {
    translation = entry
    content = prepared ?? original
    if case let .translated(language) = entry.selection, let prepared {
      preparedVersions[language] = prepared
    }
  }

  private func selectVersion(_ selection: PostTranslationSelection) async {
    guard var entry = translation, let source = original?.source else { return }
    entry.selection = selection
    apply(entry, content: selectedContent(entry))
    await service.selectVersion(source, selection)
  }
}

private enum Constants {
  static let translationTimeout = Duration.seconds(30)
}
