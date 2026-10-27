import Foundation
import NaturalLanguage
import PostTranslationService
import Translation

actor PostTranslationServiceLive {
  private let languagesInstalled: @Sendable () async -> Bool
  private let translateSegments: @Sendable ([AttributedString], [Int], PostTranslationLanguage) async throws -> [AttributedString]
  private var entries: [String: Entry] = [:]
  private var recency: [String] = []

  init(
    languagesInstalled: @escaping @Sendable () async -> Bool = PostTranslationServiceLive.languagesInstalled,
    translateSegments: @escaping @Sendable ([AttributedString], [Int], PostTranslationLanguage) async throws -> [AttributedString]
      = PostTranslationServiceLive.translatedSegments
  ) {
    self.languagesInstalled = languagesInstalled
    self.translateSegments = translateSegments
  }

  func load(_ input: PostTranslationInput) async -> PostTranslation? {
    await entry(for: input)?.translation
  }

  func translate(_ input: PostTranslationInput, to language: PostTranslationLanguage) async throws -> PostTranslation {
    let source = input.source
    let loaded = await entry(for: input)
    try Task.checkCancellation()
    guard let initial = loaded else { throw PostTranslationError.unavailable }
    let translated: [AttributedString]
    if let cached = initial.translation.translations[language] {
      translated = cached
    } else {
      translated = try await translateSegments(initial.text.segments, initial.text.indices(to: language), language)
    }
    try Task.checkCancellation()
    // Re-read after suspension so simultaneous RU and EN requests retain both cached versions.
    var entry = entries[source] ?? initial
    entry.translation.translations[language] = translated
    entry.translation.selection = .translated(language)
    store(entry, for: source)
    return entry.translation
  }

  func selectVersion(_ selection: PostTranslationSelection, for source: String) {
    guard var entry = entries[source] else { return }
    if case let .translated(language) = selection {
      guard entry.translation.translations[language] != nil else { return }
    }
    entry.translation.selection = selection
    store(entry, for: source)
  }
}

struct PostTranslationText {
  let segments: [AttributedString]
  private let languages: [Set<NLLanguage>]

  var detectedLanguages: Set<PostTranslationLanguage> {
    Set(languages.flatMap { $0 }.compactMap { PostTranslationLanguage(rawValue: $0.rawValue) })
  }

  var isSupported: Bool {
    !detectedLanguages.isEmpty && languages.joined().allSatisfy { PostTranslationLanguage(rawValue: $0.rawValue) != nil }
  }

  init(segments: [AttributedString]) {
    self.segments = segments
    languages = segments.map(Self.detectedLanguages)
  }

  func indices(to target: PostTranslationLanguage) -> [Int] {
    segments.indices.filter {
      languages[$0].contains { $0.rawValue != target.rawValue }
    }
  }
}

private extension PostTranslationServiceLive {
  private struct Entry {
    let text: PostTranslationText
    var translation: PostTranslation
  }

  private func entry(for input: PostTranslationInput) async -> Entry? {
    let text = entries[input.source]?.text ?? PostTranslationText(segments: input.segments)
    guard text.isSupported, await languagesInstalled(), !Task.isCancelled else { return nil }
    if let cached = entries[input.source] { return cached }
    let entry = Entry(text: text, translation: .init(detectedLanguages: text.detectedLanguages))
    store(entry, for: input.source)
    return entry
  }

  private func store(_ entry: Entry, for source: String) {
    recency.removeAll { $0 == source }
    recency.append(source)
    entries[source] = entry
    while recency.count > Constants.cacheLimit {
      entries.removeValue(forKey: recency.removeFirst())
    }
  }

  @concurrent
  private static func translatedSegments(
    _ segments: [AttributedString], at indices: [Int], to language: PostTranslationLanguage
  ) async throws -> [AttributedString] {
    guard !indices.isEmpty else { return segments }
    guard #available(iOS 26.4, *) else { throw PostTranslationError.unavailable }
    let session = PostTranslationSession()
    return try await withTaskCancellationHandler {
      try await session.translate(segments, at: indices, to: language)
    } onCancel: {
      Task { await session.cancel() }
    }
  }

  @concurrent
  private static func languagesInstalled() async -> Bool {
    guard #available(iOS 26.4, *) else { return false }
    let availability = LanguageAvailability(preferredStrategy: .lowLatency)
    return await availability.status(
      from: Locale.Language(identifier: PostTranslationLanguage.english.rawValue),
      to: Locale.Language(identifier: PostTranslationLanguage.russian.rawValue)) == .installed
  }
}

private extension PostTranslationText {
  private static func detectedLanguages(in text: AttributedString) -> Set<NLLanguage> {
    let prose = text.runs.map { run -> String in
      let value = String(text[run.range].characters)
      if (run.inlinePresentationIntent ?? []).contains(.code) || run.link?.absoluteString == value { return " " }
      return value
    }.joined().replacing(PostTranslationLinks.pattern, with: " ")
    var languages: Set<NLLanguage> = []
    prose.enumerateSubstrings(in: prose.startIndex..<prose.endIndex, options: .byParagraphs) { _, range, _, _ in
      prose.enumerateSubstrings(in: range, options: .bySentences) { sentence, _, _, _ in
        if let sentence, let language = detectedLanguage(in: sentence) { languages.insert(language) }
      }
    }
    return languages
  }

  private static func detectedLanguage(in text: String) -> NLLanguage? {
    guard text.unicodeScalars.filter(CharacterSet.letters.contains).count >= Constants.minimumLetters else {
      return nil
    }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let language = recognizer.dominantLanguage,
          let confidence = recognizer.languageHypotheses(withMaximum: 1)[language],
          confidence >= Constants.minimumConfidence else { return nil }
    return language
  }
}

private enum Constants {
  static let cacheLimit = 100
  static let minimumLetters = 8
  static let minimumConfidence = 0.65
}
