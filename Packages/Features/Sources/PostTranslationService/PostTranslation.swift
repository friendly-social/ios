import Foundation

public enum PostTranslationLanguage: String, CaseIterable, Sendable {
  case english = "en"
  case russian = "ru"

  public var next: Self {
    let languages = Self.allCases
    guard let index = languages.firstIndex(of: self) else { return self }
    return languages[(index + 1) % languages.count]
  }
}

public enum PostTranslationSelection: Equatable, Sendable {
  case original
  case translated(PostTranslationLanguage)
}

public struct PostTranslation: Sendable {
  public let detectedLanguages: Set<PostTranslationLanguage>
  public var translations: [PostTranslationLanguage: [AttributedString]]
  public var selection: PostTranslationSelection

  public init(
    detectedLanguages: Set<PostTranslationLanguage>,
    translations: [PostTranslationLanguage: [AttributedString]] = [:],
    selection: PostTranslationSelection = .original
  ) {
    self.detectedLanguages = detectedLanguages
    self.translations = translations
    self.selection = selection
  }
}

public enum PostTranslationError: Error {
  case unavailable
  case failed
}
