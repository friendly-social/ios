import AccountStorageService
import Dependencies
import FilesApi
import Foundation
import FriendsApi
import Models
import NetworkService
import QRCode
import UIKit

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
    let invitation = try await friendsApi.friendsGenerate(authorization, false)
    return try Deeplink.invitationURL(for: invitation.token)
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
