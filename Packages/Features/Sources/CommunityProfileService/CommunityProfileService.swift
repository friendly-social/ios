import CommunityService
import DependenciesMacros
import Foundation

@DependencyClient
public struct CommunityProfileService: Sendable {
  public var currentSession: @Sendable () -> CommunitySession? = {
    assertionFailure("CommunityProfileService.currentSession unimplemented")
    return nil
  }
  public var isCurrentSession: @Sendable (CommunitySession) -> Bool = { _ in
    assertionFailure("CommunityProfileService.isCurrentSession unimplemented")
    return false
  }
  public var cachedOwner: @Sendable (CommunitySession) -> CommunityPost.Owner? = { _ in
    assertionFailure("CommunityProfileService.cachedOwner unimplemented")
    return nil
  }
  public var loadOwner: @Sendable (CommunitySession) async throws -> CommunityPost.Owner
  public var avatarURL: @Sendable (CommunityPost.Owner.Avatar) -> URL = { _ in
    assertionFailure("CommunityProfileService.avatarURL unimplemented")
    return URL(fileURLWithPath: "/")
  }
  public var clearSession: @Sendable () -> Void = {
    assertionFailure("CommunityProfileService.clearSession unimplemented")
  }
}

public struct CommunitySession: Sendable, Equatable {
  public let accountID: Int64
  public let token: String
  public let sessionID: String

  public init(accountID: Int64, token: String, sessionID: String) {
    self.accountID = accountID
    self.token = token
    self.sessionID = sessionID
  }
}
