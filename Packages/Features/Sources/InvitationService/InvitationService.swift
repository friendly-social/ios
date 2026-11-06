import DependenciesMacros
import Foundation
import UIKit

@DependencyClient
public struct InvitationService: Sendable {
  public var generateInvitation: @Sendable (Bool) async throws -> InvitationCode
}

public struct InvitationCode: Sendable {
  public let url: URL
  public let image: UIImage
  public let expiration: Date

  public init(url: URL, image: UIImage, expiration: Date) {
    self.url = url
    self.image = image
    self.expiration = expiration
  }
}
