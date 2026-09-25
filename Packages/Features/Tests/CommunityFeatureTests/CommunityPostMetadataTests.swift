import CommunityService
@testable import CommunityApiLive
import Foundation
import Testing

struct CommunityPostMetadataTests {
  @Test(arguments: ["text", "owner", "edited", "instant"])
  func publishedPostRejectsMissingRequiredFields(field: String) throws {
    var object: [String: Any] = [
      "id": 1, "accessHash": "hash", "type": "plain", "text": "Hello",
      "owner": ["id": 7, "accessHash": "owner-hash", "nickname": "Alex"],
      "edited": false, "instant": "2026-09-23T10:30:00Z",
    ]
    object.removeValue(forKey: field)
    let data = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CommunityPostResponse.self, from: data)
    }
  }

  @Test(arguments: ["id", "accessHash"])
  func authorIdentityIsRequired(field: String) throws {
    var owner: [String: Any] = ["id": 7, "accessHash": "hash", "nickname": "Alex"]
    owner.removeValue(forKey: field)
    let data = try JSONSerialization.data(withJSONObject: [
      "id": 1, "accessHash": "hash", "text": "Hello", "owner": owner,
      "edited": false, "instant": "2026-09-23T10:30:00Z",
    ])
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CommunityPostResponse.self, from: data)
    }
  }

  @Test(arguments: ["", "not-a-date"])
  func invalidDateIsRejected(instant: String) throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "id": 1, "accessHash": "hash", "type": "deleted", "instant": instant,
    ])
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CommunityPostResponse.self, from: data)
    }
  }

  @Test func unknownServerTypeIsRejected() throws {
    let data = Data(#"{"id":1,"accessHash":"hash","type":"awaitingDetails","instant":"2026-09-23T10:30:00Z"}"#.utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CommunityPostResponse.self, from: data)
    }
  }

  @Test func decodesAuthorAvatarAndFractionalTimestamp() throws {
    let page = try JSONDecoder().decode(CommunityPageResponse.self, from: Data(#"""
      {"data":[{"id":1,"accessHash":"post-hash","text":"Hello","edited":true,
      "instant":"2026-09-23T10:30:00.123456Z",
      "owner":{"id":7,"accessHash":"user-hash","nickname":"Автор",
      "avatar":{"id":9,"accessHash":"file-hash"}}}],"nextId":null}
      """#.utf8)).page
    let post = try #require(page.data.first)
    #expect(post.owner?.id == 7)
    #expect(post.owner?.accessHash == "user-hash")
    #expect(post.owner?.avatar?.id == 9)
    #expect(post.owner?.avatar?.accessHash == "file-hash")
    #expect(post.edited == true)
    #expect(post.date != nil)
  }

  @Test(arguments: ["2026-09-23T10:30:00Z", "2026-09-23T13:30:00+03:00"])
  func parsesTimestampWithoutFractionalSeconds(instant: String) throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "id": 1, "accessHash": "hash", "type": "deleted", "instant": instant,
    ])
    let post = try JSONDecoder().decode(CommunityPostResponse.self, from: data).post
    #expect(post.date == Date(timeIntervalSince1970: 1_790_159_400))
  }

  @Test func localPostHasNoInventedAuthorOrTimestamp() {
    let post = CommunityPost.awaitingDetails(.init(descriptor: .init(id: 1, accessHash: "hash"), text: "Hello"))
    #expect(post.date == nil)
    #expect(post.owner?.id == nil)
    #expect(post.owner?.avatar == nil)
  }
}
