public import Dependencies
public import PostTranslationService

extension PostTranslationService: DependencyKey {
  public static var liveValue: Self {
    guard #available(iOS 26.4, *) else {
      return Self(
        load: { _ in nil },
        translate: { _, _ in throw PostTranslationError.unavailable },
        selectVersion: { _, _ in })
    }
    let live = PostTranslationServiceLive()
    return Self(
      load: { await live.load($0) },
      translate: { try await live.translate($0, to: $1) },
      selectVersion: { await live.selectVersion($1, for: $0) })
  }
}
