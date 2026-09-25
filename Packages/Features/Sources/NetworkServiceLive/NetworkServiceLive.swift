import AccountStorageService
import Dependencies
import FilesApi
import Foundation
import FriendsApi
import NetworkService
import QRCode
import UIKit
import URLMacro

struct NetworkServiceLive: Sendable {
  @Dependency(FriendsApi.self) private var friendsApi
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(AccountStorageService.self) private var storage

  func loadFriends() async throws -> [NetworkFriend] {
    let authorization = try storage.loadAuthorization()
    let details = try await friendsApi.networkDetails(authorization)
    return details.friends.map { friend in
      NetworkFriend(
        id: friend.id,
        accessHash: friend.accessHash,
        avatarURL: friend.avatar.map { filesApi.downloadURL(for: $0) },
        nickname: friend.nickname
      )
    }
  }

  func generateInvitationURL() async throws -> URL {
    let authorization = try storage.loadAuthorization()
    let token = try await friendsApi.friendsGenerate(authorization)
    guard let reference = "add/\(authorization.id.int64)/\(token.string)"
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: Constants.landingURL.absoluteString + "#?reference=\(reference)")
    else { throw URLError(.badURL) }
    return url
  }

  func generateQRCode(for url: URL) -> UIImage? {
    guard let image = try? QRCode.build
      .text(url.absoluteString)
      .quietZonePixelCount(3)
      .background.cornerRadius(3)
      .eye.shape(QRCode.EyeShape.RoundedOuter())
      .generate.image(dimension: 600)
    else { return nil }
    return UIImage(cgImage: image)
  }
}

private enum Constants {
  static let landingURL = #URL("https://getfriend.ly/#/")
}
