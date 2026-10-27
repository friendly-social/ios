import CommunityService
import DependenciesMacros

@DependencyClient
public struct CommunityDraftService: Sendable {
  public var postDraftUpdates: @Sendable (Int64, String) async throws -> AsyncStream<String?>
  public var postDrafts: @Sendable (
    Int64, String, @escaping @Sendable () -> Bool
  ) -> CommunityDrafts = { _, _, _ in
    .init(
      load: { throw CommunityError.unavailable },
      save: { _ in throw CommunityError.unavailable },
      remove: { throw CommunityError.unavailable }
    )
  }
  public var replyDrafts: @Sendable (
    PostDescriptor, Int64, String, @escaping @Sendable () -> Bool
  ) -> CommunityDrafts = { _, _, _, _ in
    .init(
      load: { throw CommunityError.unavailable },
      save: { _ in throw CommunityError.unavailable },
      remove: { throw CommunityError.unavailable }
    )
  }
  public var replyDraft: @Sendable (String) -> CommunityReplyDraft = { .markdown($0) }
  public var revokePostDrafts: @Sendable (Int64, String) async throws -> Void
}

public struct CommunityDrafts {
  public var load: () async throws -> CommunityDraftSnapshot<String>?
  public var save: (CommunityDraftSnapshot<String>) async throws -> Void
  public var remove: () async throws -> Void

  public init(
    load: @escaping () async throws -> CommunityDraftSnapshot<String>?,
    save: @escaping (CommunityDraftSnapshot<String>) async throws -> Void,
    remove: @escaping () async throws -> Void
  ) {
    self.load = load
    self.save = save
    self.remove = remove
  }
}

public struct CommunityDraftSnapshot<Content> {
  public let content: Content
  public let cursor: Int?

  public init(content: Content, cursor: Int? = nil) {
    self.content = content
    self.cursor = cursor
  }
}

extension CommunityDraftSnapshot: Equatable where Content: Equatable {}
extension CommunityDraftSnapshot: Sendable where Content: Sendable {}

public enum CommunityReplyDraft: Sendable, Equatable, Codable {
  case plainText(String)
  case markdown(String)
}
