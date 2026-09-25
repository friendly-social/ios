import CommunityDraftService
import DependenciesMacros

@DependencyClient
public struct CommunityDraftStorageService: Sendable {
  public var postDraftUpdates: @Sendable (Key) async throws -> AsyncStream<String?>
  public var loadPost: @Sendable (Key) async throws -> String?
  public var savePost: @Sendable (Key, String) async throws -> Void
  public var loadReply: @Sendable (Key) async throws -> CommunityReplyDraft?
  public var saveReply: @Sendable (Key, CommunityReplyDraft) async throws -> Void
  public var remove: @Sendable (Key) async throws -> Void
  public var revokePost: @Sendable (Key) async throws -> Void
}

extension CommunityDraftStorageService {
  public struct Key: Sendable {
    public let accountID: Int64
    public let sessionID: String
    public let parentID: Int64?

    public init(accountID: Int64, sessionID: String, parentID: Int64? = nil) {
      self.accountID = accountID
      self.sessionID = sessionID
      self.parentID = parentID
    }
  }
}
