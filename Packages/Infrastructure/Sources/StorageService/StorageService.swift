import DependenciesMacros
import Foundation

@DependencyClient
public struct SecureStorageService: Sendable {
  public var save: @Sendable (Data, String) throws -> Void
  public var load: @Sendable (String) throws -> Data?
  public var contains: @Sendable (String) throws -> Bool
  public var remove: @Sendable (String) throws -> Void
}
