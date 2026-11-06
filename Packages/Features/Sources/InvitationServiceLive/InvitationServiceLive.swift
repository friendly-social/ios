import AccountStorageService
import Dependencies
import Foundation
import FriendsApi
import InvitationService
import Models
import QRCode
import UIKit

struct InvitationServiceLive: Sendable {
  @Dependency(FriendsApi.self) private var friendsApi
  @Dependency(AccountStorageService.self) private var storage

  func generateInvitation(force: Bool) async throws -> InvitationCode {
    let authorization = try storage.loadAuthorization()
    let invitation = try await friendsApi.friendsGenerate(authorization, force)
    let url = try Deeplink.invitationURL(for: invitation.token)
    let image = try await generateQRCode(for: url)
    return .init(url: url, image: image, expiration: invitation.expiration)
  }
}

private extension InvitationServiceLive {
  private func generateQRCode(for url: URL) async throws -> UIImage {
    try await withThrowingTaskGroup(of: UIImage.self) { group in
      group.addTask(priority: .high) {
        try Task.checkCancellation()
        let image = try self.renderQRCode(for: url)
        try Task.checkCancellation()
        return image
      }
      guard let image = try await group.next() else { throw CancellationError() }
      return image
    }
  }

  private func renderQRCode(for url: URL) throws -> UIImage {
    let builder = try QRCode.build
      .text(url.absoluteString)
      .errorCorrection(.high)
      .quietZonePixelCount(4)
    guard let iconURL = Bundle.module.url(forResource: "InvitationIcon", withExtension: "png"),
          let logo = UIImage(contentsOfFile: iconURL.path)?.cgImage else {
      throw CocoaError(.fileReadCorruptFile)
    }
    builder.logo(image: logo, unitRect: Constants.logoRect, inset: Constants.logoInset)
    return try .init(cgImage: builder.generate.image(dimension: Constants.imageSize))
  }
}

private enum Constants {
  static let logoInset = 6.0
  static let imageSize = 1024
  static let logoRect = CGRect(x: 0.42, y: 0.42, width: 0.16, height: 0.16)
}
