import AccountStorageService
import CustomDump
import Dependencies
import FilesApi
import Foundation
import FriendsApi
import Models
import ProfileApi
import ProfileService
import ProfileServiceLive
import Synchronization
import Testing

struct ProfileFriendsServiceTests {
  @Test func friendsAreLoadedDirectlyAndKeepUsersWithoutAvatars() async throws {
    let authorization = try authorization()
    let avatar = try FileDescriptor(id: FileId(9), accessHash: FileAccessHash(String(repeating: "c", count: 256)))
    let users = try [friend(2, avatar: nil), friend(3, avatar: avatar)]
    let imageURL = try #require(URL(string: "https://example.com/avatar.jpg"))
    var storage = AccountStorageService()
    storage.loadAuthorization = { authorization }
    var api = FriendsApi()
    api.networkDetails = { received in
      expectNoDifference(received.id, authorization.id)
      expectNoDifference(received.token, authorization.token)
      return NetworkDetails(friends: users)
    }
    var files = FilesApi()
    files.downloadURL = { _ in imageURL }
    let service = withDependencies {
      $0[AccountStorageService.self] = storage
      $0[FriendsApi.self] = api
      $0[FilesApi.self] = files
    } operation: { ProfileService.liveValue }
    let friends = try #require(try await service.loadFriends())
    expectNoDifference(friends.map(\.id), users.map(\.id))
    expectNoDifference(friends.map(\.avatarURL), [nil, imageURL])
    expectNoDifference(friends.map(\.nickname.string), ["Friend 2", "Friend 3"])
  }

  @Test func unifiedLoaderReturnsOwnProfile() async throws {
    let authorization = try authorization()
    let user = try friend(1, avatar: nil, email: "anna@example.com")
    var storage = AccountStorageService()
    storage.loadAuthorization = { authorization }
    var api = ProfileApi()
    api.usersDetailsWithFriends = { received, id, hash in
      expectNoDifference(received.token, authorization.token)
      expectNoDifference(id, authorization.id)
      expectNoDifference(hash, authorization.accessHash)
      return ProfileDetails(user: user, friendship: .none, commonFriends: [])
    }
    let service = withDependencies {
      $0[AccountStorageService.self] = storage
      $0[ProfileApi.self] = api
    } operation: { ProfileService.liveValue }
    let loaded = try #require(try await service.loadProfile(.current))
    expectNoDifference(loaded.info.nickname, user.nickname)
    expectNoDifference(loaded.info.email, "anna@example.com")
    if case .own = loaded.relationship {} else { Issue.record("Expected own profile") }
    #expect(loaded.commonFriends == nil)
  }

  @Test func unifiedLoaderReturnsFriendshipAndCommonFriends() async throws {
    let authorization = try authorization()
    let user = try friend(2, avatar: nil)
    let common = try friend(3, avatar: nil)
    var storage = AccountStorageService()
    storage.loadAuthorization = { authorization }
    var api = ProfileApi()
    api.usersDetailsWithFriends = { _, id, hash in
      expectNoDifference(id, user.id)
      expectNoDifference(hash, user.accessHash)
      return ProfileDetails(user: user, friendship: .incomingRequest, commonFriends: [common])
    }
    let service = withDependencies {
      $0[AccountStorageService.self] = storage
      $0[ProfileApi.self] = api
    } operation: { ProfileService.liveValue }
    let loaded = try #require(try await service.loadProfile(.other(id: user.id, accessHash: user.accessHash)))
    expectNoDifference(loaded.info.nickname, user.nickname)
    guard case let .other(friendship, friends) = loaded.relationship else {
      Issue.record("Expected another user's profile")
      return
    }
    if case .incomingRequest = friendship {} else { Issue.record("Expected incoming request") }
    expectNoDifference(friends.map(\.id), [common.id])
  }

  @Test func unifiedProfileResultIsDiscardedAfterSessionChange() async throws {
    let original = try authorization()
    let replacement = try authorization(token: "b")
    let user = try friend(1, avatar: nil)
    let calls = Mutex(0)
    var storage = AccountStorageService()
    storage.loadAuthorization = {
      calls.withLock { value in value += 1; return value == 1 ? original : replacement }
    }
    var api = ProfileApi()
    api.usersDetailsWithFriends = { _, _, _ in ProfileDetails(user: user, friendship: .none, commonFriends: []) }
    let service = withDependencies {
      $0[AccountStorageService.self] = storage
      $0[ProfileApi.self] = api
    } operation: { ProfileService.liveValue }
    #expect(try await service.loadProfile(.current) == nil)
  }

  @Test func resultIsDiscardedIfSessionChangesDuringRequest() async throws {
    let original = try authorization()
    let replacement = try authorization(token: "b")
    let calls = Mutex(0)
    var storage = AccountStorageService()
    storage.loadAuthorization = {
      calls.withLock { value in value += 1; return value == 1 ? original : replacement }
    }
    var api = FriendsApi()
    api.networkDetails = { _ in NetworkDetails(friends: []) }
    let service = withDependencies {
      $0[AccountStorageService.self] = storage
      $0[FriendsApi.self] = api
    } operation: { ProfileService.liveValue }
    #expect(try await service.loadFriends() == nil)
  }
}

private extension ProfileFriendsServiceTests {
  private func authorization(token: Character = "a") throws -> Authorization {
    try Authorization(token: Token(String(repeating: String(token), count: 256)), id: UserId(1),
                      accessHash: UserAccessHash(String(repeating: "a", count: 256)))
  }

  private func friend(_ id: Int64, avatar: FileDescriptor?, email: String? = nil) throws -> UserDetails {
    try UserDetails(id: UserId(id), accessHash: UserAccessHash(String(repeating: "a", count: 256)),
      nickname: Nickname("Friend \(id)"), description: UserDescription("Hello"), interests: [],
      avatar: avatar, socialLink: nil, email: email)
  }
}
