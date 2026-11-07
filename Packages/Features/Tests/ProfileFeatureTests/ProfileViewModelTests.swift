import CustomDump
import FriendlyUIKit
import Models
import Testing

@MainActor
struct ProfileViewModelTests {
  @Test(arguments: [(0, 0, 0), (3, 3, 0), (5, 5, 0), (10, 5, 5), (17, 5, 12)])
  func commonFriendsPreviewLimitsAvatars(count: Int, shown: Int, remaining: Int) throws {
    let friends = try (0..<count).map { index in
      try FriendSummary(id: UserId(Int64(index)), accessHash: UserAccessHash(String(repeating: "b", count: 256)),
                       nickname: Nickname("Friend \(index)"), avatarURL: nil)
    }
    let preview = FriendsPreview(friends: friends)
    expectNoDifference(preview.avatars.count, shown)
    expectNoDifference(preview.remainingCount, remaining)
    expectNoDifference(preview.avatars.map(\.id), Array(friends.prefix(shown)).map(\.id))
    #expect(!preview.names.contains("Friend 5"))
  }
}
