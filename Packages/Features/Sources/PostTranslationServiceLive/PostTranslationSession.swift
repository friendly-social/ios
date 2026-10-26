import Foundation
import PostTranslationService
@preconcurrency import Translation

// Each request owns one session; concurrent access is limited to the SDK's cancel operation.
@available(iOS 26.4, *)
actor PostTranslationSession {
  private var session: TranslationSession?

  func translate(
    _ segments: [AttributedString], at indices: [Int], to language: PostTranslationLanguage
  ) async throws -> [AttributedString] {
    try Task.checkCancellation()
    let session = Self.makeSession(to: language)
    self.session = session
    defer { session.cancel(); self.session = nil }
    do {
      var result = segments
      for index in indices {
        try Task.checkCancellation()
        result[index] = try await translatedText(segments[index], session: session)
      }
      try Task.checkCancellation()
      return result
    } catch {
      try Task.checkCancellation()
      throw PostTranslationError.failed
    }
  }

  func cancel() { session?.cancel() }
}

@available(iOS 26.4, *)
private extension PostTranslationSession {
  private static func makeSession(to language: PostTranslationLanguage) -> TranslationSession {
    let source = Locale.Language(identifier: language.next.rawValue)
    let target = Locale.Language(identifier: language.rawValue)
    return TranslationSession(installedSource: source, target: target, preferredStrategy: .lowLatency)
  }

  private func translatedText(
    _ text: AttributedString, session: TranslationSession
  ) async throws -> AttributedString {
    let response = try await session.translate(Self.protectedText(text))
    guard !response.targetText.isEmpty else { throw PostTranslationError.failed }
    return response.attributedTargetText ?? AttributedString(response.targetText)
  }

  private static func protectedText(_ original: AttributedString) -> AttributedString {
    var text = original
    let ranges = text.runs.filter { ($0.inlinePresentationIntent ?? []).contains(.code) }.map(\.range)
    for range in ranges { text[range].skipsTranslation = true }
    for match in String(text.characters).matches(of: PostTranslationLinks.pattern) {
      if let range = Range(match.range, in: text) { text[range].skipsTranslation = true }
    }
    return text
  }
}
