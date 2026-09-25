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
  public var detailDrafts: @Sendable (
    PostDescriptor, Int64, String, @escaping @Sendable () -> Bool
  ) -> CommunityReplyDrafts = { _, _, _, _ in
    .init(
      load: { throw CommunityError.unavailable },
      save: { _ in throw CommunityError.unavailable },
      remove: { throw CommunityError.unavailable }
    )
  }
  public var replyDraft: @Sendable (String) -> CommunityReplyDraft = { .markdown($0) }
  public var revokePostDrafts: @Sendable (Int64, String) async throws -> Void
}

public struct CommunityDraftHandle<Content> {
  public var load: () async throws -> Content?
  public var save: (Content) async throws -> Void
  public var remove: () async throws -> Void

  public init(
    load: @escaping () async throws -> Content?,
    save: @escaping (Content) async throws -> Void,
    remove: @escaping () async throws -> Void
  ) {
    self.load = load
    self.save = save
    self.remove = remove
  }
}

public typealias CommunityDrafts = CommunityDraftHandle<String>
public typealias CommunityReplyDrafts = CommunityDraftHandle<CommunityReplyDraft>

public enum CommunityReplyDraft: Sendable, Equatable, Codable {
  case plainText(String)
  case markdown(String)

  public var text: String {
    switch self {
    case let .plainText(text), let .markdown(text): text
    }
  }
}
