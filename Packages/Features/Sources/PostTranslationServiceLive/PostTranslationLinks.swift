enum PostTranslationLinks {
  static var pattern: Regex<Substring> {
    #/(?:https?:\/\/|www\.)[^\s<>]+/#
  }
}
