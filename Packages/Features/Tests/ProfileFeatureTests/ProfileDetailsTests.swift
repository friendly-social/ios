import CustomDump
import Foundation
import Models
import ProfileApi
@testable import ProfileApiLive
import Testing

struct ProfileDetailsTests {
  @Test(arguments: ["friends", "incomingRequest", "outgoingRequest", "outgoingDecline", "none"])
  func decodesFriendshipAndFriendsWithoutAvatars(_ friendship: String) throws {
    let result = try decode(friendship)
    expectNoDifference(result.friendship.rawValue, friendship)
    expectNoDifference(result.commonFriends.map(\.nickname.string), ["Anna"])
    #expect(result.commonFriends[0].avatar == nil)
  }

  @Test func rejectsUnknownFriendshipAtApiBoundary() throws {
    #expect(throws: DecodingError.self) { try decode("unknown") }
  }

  @Test(arguments: [1025, 1063, 10_240])
  func acceptsServerDescriptionsBeyondThePreviousLimit(_ length: Int) throws {
    let description = String(repeating: "a", count: length)
    let result = try decode("friends", description: description)
    #expect(result.user.description.string == description)
    #expect(result.commonFriends[0].description.string == description)
  }

  @Test func rejectsDescriptionsBeyondTheServerLimit() {
    #expect(throws: UserDescription.Error.self) {
      try UserDescription(String(repeating: "a", count: 10_241))
    }
  }
}

private extension ProfileDetailsTests {
  private func decode(_ friendship: String, description: String = "Hello") throws -> ProfileDetails {
    let hash = String(repeating: "a", count: 256)
    let user: [String: Any] = [
      "id": 1, "accessHash": hash, "nickname": "Anna", "description": description,
      "interests": ["Coffee"], "avatar": NSNull(), "socialLink": NSNull(),
      "email": NSNull(), "friendship": friendship,
    ]
    let json = try JSONSerialization.data(withJSONObject: ["user": user, "commonFriends": [user]])
    return try JSONDecoder().decode(ProfileDetailsDTO.self, from: json).details()
  }
}
