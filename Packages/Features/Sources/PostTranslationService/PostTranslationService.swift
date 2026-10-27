import DependenciesMacros
import Foundation

@DependencyClient
public struct PostTranslationService: Sendable {
  public var load: @Sendable (PostTranslationInput) async -> PostTranslation? = { _ in nil }
  public var translate: @Sendable (PostTranslationInput, PostTranslationLanguage) async throws -> PostTranslation
  public var selectVersion: @Sendable (String, PostTranslationSelection) async -> Void
}

public struct PostTranslationInput: Sendable {
  public let source: String
  public let segments: [AttributedString]

  public init(source: String, segments: [AttributedString]) {
    self.source = source
    self.segments = segments
  }
}
