import DependenciesMacros
import Models

@DependencyClient
public struct AccountStorageService: Sendable {
  public var saveAuthorization: @Sendable (Authorization) throws -> Void
  public var loadAuthorization: @Sendable () throws -> Authorization
  public var hasAuthorization: @Sendable () throws -> Bool
  public var clearAuthorization: @Sendable () -> Void = {}
  public var getHasFriend: @Sendable () throws -> Bool
  public var addFriend: @Sendable () throws -> Void
  public var saveCommunityProfile: @Sendable (CachedAccountProfile) throws -> Void
  public var loadCommunityProfile: @Sendable (Int64) throws -> CachedAccountProfile?
}
