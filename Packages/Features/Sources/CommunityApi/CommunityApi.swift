import CommunityService
import DependenciesMacros

@DependencyClient
public struct CommunityApi: Sendable {
  public var publish: @Sendable (String, PostDescriptor?, CommunityCredentials) async throws -> PostDescriptor
  public var edit: @Sendable (Int64, String, CommunityCredentials) async throws -> Void
  public var delete: @Sendable (Int64, CommunityCredentials) async throws -> Void
  public var list: @Sendable (String?, CommunityCredentials) async throws -> CommunityPage
  public var details: @Sendable (PostDescriptor, CommunityCredentials) async throws -> CommunityPostDetails
  public var replies: @Sendable (PostDescriptor, String, CommunityCredentials) async throws -> CommunityReplyPage
}

public struct CommunityCredentials: Sendable, Equatable {
  public let accountID: Int64
  public let token: String

  public init(accountID: Int64, token: String) {
    self.accountID = accountID
    self.token = token
  }
}
