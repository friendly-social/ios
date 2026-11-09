import CommunityMarkdownService
import CustomDump
import Dependencies
import DiscoveryFeedService
@testable import FeedFeature
import FriendlyUIKit
import Models
@testable import ProfileFeature
import ProfileService
import ProfileServiceLive
import SwiftUI
import Synchronization
import Testing

@MainActor
struct ProfileViewModelTests {
  @Test func feedOpensCommonFriendsIncludingThoseWithoutAvatars() async throws {
    let hash = try UserAccessHash(String(repeating: "b", count: 256))
    let friend = FriendSummary(id: UserId(2), accessHash: hash,
      nickname: try Nickname("Maria"), avatarURL: nil)
    let candidate = DiscoveryCandidate(id: UserId(1), accessHash: hash, avatarURL: nil,
      nickname: try Nickname("Anna"), description: try UserDescription("Hello"),
      interests: [], commonFriends: [friend], isRequest: false, isExtendedNetwork: true)
    var service = DiscoveryFeedService()
    service.loadCandidates = { [candidate] }
    let model = withDependencies {
      $0[DiscoveryFeedService.self] = service
    } operation: { FeedViewModel() }
    await model.reload()
    guard case let .success(entries) = model.state, let entry = entries.first else {
      Issue.record("Expected a candidate")
      return
    }
    expectNoDifference(entry.friendsPreview.names, "Maria")
    #expect(entry.friendsPreview.avatars.first?.url == nil)
    entry.onOpenFriends()
    guard case let .friends(route) = model.destination else {
      Issue.record("Expected the common friends screen")
      return
    }
    expectNoDifference(route.friends.map(\.id), [friend.id])
    expectNoDifference(route.friends.first?.accessHash, hash)
  }

  @Test(arguments: [false, true])
  func cancelledFeedRequestsDoNotChangeState(fails: Bool) async {
    let (started, start) = AsyncStream<Void>.makeStream()
    let (resumed, resume) = AsyncStream<Void>.makeStream()
    let response = Task { for await _ in resumed { break } }
    var service = DiscoveryFeedService()
    service.loadCandidates = {
      start.yield()
      await response.value
      if fails { throw Failure.unavailable }
      return []
    }
    let model = withDependencies {
      $0[DiscoveryFeedService.self] = service
    } operation: { FeedViewModel() }
    let load = Task { await model.reload() }
    var iterator = started.makeAsyncIterator()
    _ = await iterator.next()
    load.cancel()
    resume.yield()
    resume.finish()
    await load.value
    if case .loading = model.state {} else { Issue.record("A cancelled load changed the state") }
  }

  @Test func requestReloadsServerFriendship() async throws {
    let calls = Mutex(0)
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    let details = try Self.otherProfile(friendship: .outgoingRequest)
    service.loadProfile = { _ in details }
    service.requestFriend = { _, _ in calls.withLock { $0 += 1 } }
    let model = try makeModel(service)
    await model.requestFriend()
    expectNoDifference(calls.withLock { $0 }, 1)
    guard case let .success(profile) = model.state else {
      Issue.record("Expected refreshed profile")
      return
    }
    if case .other(friendship: .outgoingRequest, commonFriends: _) = profile.relationship {} else {
      Issue.record("Expected server friendship")
    }
  }

  @Test func failedRequestLeavesProfileUsable() async throws {
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    let details = try Self.otherProfile(friendship: .none)
    service.loadProfile = { _ in details }
    service.requestFriend = { _, _ in throw Failure.unavailable }
    let model = try makeModel(service)
    await model.reload()
    await model.requestFriend()
    if case .success = model.state {} else { Issue.record("Expected a loaded profile") }
    #expect(model.alertError != nil)
    #expect(!model.isUpdatingFriendship)
  }

  @Test func ownFriendsFailureLeavesProfileAndRetryLoadsFriends() async throws {
    let profile = ProfileInfo(avatarUrl: nil, nickname: try Nickname("Anna"),
      description: try UserDescription("Hello"), interests: [], socialUrl: nil, email: nil)
    let friend = try Self.commonFriend()
    let calls = Mutex(0)
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadProfile = { _ in LoadedProfile(info: profile, relationship: .own) }
    service.loadFriends = {
      let count = calls.withLock { value in value += 1; return value }
      if count == 1 { throw Failure.unavailable }
      return [friend]
    }
    let model = makeOwnModel(service)
    await model.reload()
    if case .failed = model.friendsState {} else { Issue.record("Expected friends error") }
    if case .success = model.state {} else { Issue.record("Expected profile to remain visible") }
    await model.loadFriends()
    expectNoDifference(model.displayedFriends?.map(\.id), [friend.id])
    model.showProfileFriends()
    #expect(model.navigationDestination == .commonFriends)
  }

  @Test func refreshKeepsLoadedFriendsVisible() async throws {
    let friend = try Self.commonFriend()
    let calls = Mutex(0)
    let (started, startedContinuation) = AsyncStream<Void>.makeStream()
    let (resume, resumeContinuation) = AsyncStream<Void>.makeStream()
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadFriends = {
      let count = calls.withLock { value in value += 1; return value }
      if count > 1 {
        startedContinuation.yield()
        for await _ in resume { break }
      }
      return [friend]
    }
    let model = makeOwnModel(service)
    await model.loadFriends()
    let refresh = Task { await model.loadFriends() }
    var iterator = started.makeAsyncIterator()
    _ = await iterator.next()
    expectNoDifference(model.displayedFriends?.map(\.id), [friend.id])
    resumeContinuation.yield()
    resumeContinuation.finish()
    await refresh.value
    expectNoDifference(model.displayedFriends?.map(\.id), [friend.id])
  }

  @Test func failedRefreshKeepsFriendsAndOffersRetry() async throws {
    let friend = try Self.commonFriend()
    let calls = Mutex(0)
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadFriends = {
      let count = calls.withLock { value in value += 1; return value }
      if count > 1 { throw Failure.unavailable }
      return [friend]
    }
    let model = makeOwnModel(service)
    await model.loadFriends()
    await model.loadFriends()
    expectNoDifference(model.displayedFriends?.map(\.id), [friend.id])
    #expect(model.friendsRefreshFailed)
  }

  @Test func invitationUsesTheProfileSheet() {
    let model = ProfileViewModel(mode: .selfProfile(.init(routeToSignUp: {})))
    model.showInvitation()
    #expect(model.sheetDestination == .invitation)
    #expect(model.navigationDestination == nil)
  }

  @Test func confirmingEmailHidesThePromptWhileTheSuccessStepStaysOpen() async throws {
    let info = ProfileInfo(
      avatarUrl: nil,
      nickname: try Nickname("Kinokot"),
      description: try UserDescription("Hello"),
      interests: [],
      socialUrl: nil,
      email: nil
    )
    var service = ProfileService()
    service.loadProfile = { _ in LoadedProfile(info: info, relationship: .own) }
    service.prepareDescription = { _ in nil }
    service.loadFriends = { [] }
    let model = makeOwnModel(service)
    await model.reload()
    #expect(model.canBindEmail)
    model.showEmailBinding()
    #expect(model.navigationDestination == .bindEmail)
    #expect(model.sheetDestination == nil)
    model.emailBindingConfirmed("kinokot@example.com")
    #expect(!model.canBindEmail)
    #expect(model.navigationDestination == .bindEmail)
    model.closeEmailBinding()
    model.showEmailBinding()
    #expect(model.navigationDestination == nil)
  }

  @Test func liveDescriptionPreparationUsesSharedMarkdownParser() async {
    let source = "# Title\n\n<img src=\"https://example.com/icon.gif\" width=\"23\" height=\"23\">"
    let document = await ProfileService.liveValue.prepareDescription(source)
    guard case .heading(level: 1, _) = document?.blocks.first?.kind,
          case let .paragraph(content) = document?.blocks.last?.kind,
          case .image = content.first?.kind else {
      Issue.record("Expected a heading and HTML image")
      return
    }
  }

  @Test func otherProfilePreparesMarkdownBeforeRendering() async throws {
    let profile = ProfileInfo(avatarUrl: nil, nickname: try Nickname("Anna"),
      description: try UserDescription("# Hello"), interests: [], socialUrl: nil, email: nil)
    let details = LoadedProfile(info: profile, relationship: .other(friendship: .none, commonFriends: []))
    var service = ProfileService()
    service.loadProfile = { _ in details }
    service.prepareDescription = { try? MarkdownDocument(source: $0) }
    let model = try makeModel(service)
    await model.reload()
    guard case .heading(level: 1, _) = model.descriptionDocument?.blocks.first?.kind else {
      Issue.record("Expected rendered heading")
      return
    }
  }

  @Test func ownProfilePreparesMarkdownBeforeRendering() async throws {
    let profile = ProfileInfo(avatarUrl: nil, nickname: try Nickname("Anna"),
      description: try UserDescription("# Hello"), interests: [], socialUrl: nil, email: nil)
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadProfile = { _ in LoadedProfile(info: profile, relationship: .own) }
    service.loadFriends = { [] }
    service.prepareDescription = { try? MarkdownDocument(source: $0) }
    let model = makeOwnModel(service)
    await model.reload()
    guard case .heading(level: 1, _) = model.descriptionDocument?.blocks.first?.kind else {
      Issue.record("Expected rendered heading")
      return
    }
  }

  @Test func photoDestinationComparesAndHashesByURL() throws {
    let url = try #require(URL(string: "https://example.com/avatar.jpg"))
    let first = ProfileViewModel.Photo(id: url, image: Image(systemName: "person"),
      imageSize: nil, sourceFrame: .zero)
    let refreshed = ProfileViewModel.Photo(id: url, image: Image(systemName: "photo"),
      imageSize: CGSize(width: 800, height: 600), sourceFrame: CGRect(x: 10, y: 20, width: 70, height: 70))
    let destination = ProfileViewModel.Destination.photo(first)
    expectNoDifference(destination, .photo(refreshed))
    expectNoDifference(Set([destination, .photo(refreshed), .edit, .invitation, .commonFriends]).count, 4)
  }

  @Test func ownAvatarOpensPhotoViewer() async throws {
    let url = try #require(URL(string: "https://example.com/avatar.jpg"))
    let profile = ProfileInfo(avatarUrl: url, nickname: try Nickname("Anna"),
      description: try UserDescription("Hello"), interests: [], socialUrl: nil, email: nil)
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadProfile = { _ in LoadedProfile(info: profile, relationship: .own) }
    service.loadFriends = { [] }
    let model = makeOwnModel(service)
    await model.reload()
    let frame = CGRect(x: 10, y: 20, width: 70, height: 70)
    model.showAvatar(Image(systemName: "person"), imageSize: CGSize(width: 800, height: 600), sourceFrame: frame)
    guard case let .photo(photo) = model.photoDestination else {
      Issue.record("Expected a photo destination")
      return
    }
    expectNoDifference(photo.id, url)
    expectNoDifference(photo.sourceFrame, frame)
    #expect(model.sheetDestination == nil)
  }

  @Test func avatarWithoutImageDoesNotOpenViewer() async throws {
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadProfile = { _ in try Self.otherProfile(friendship: .none) }
    let model = try makeModel(service)
    await model.reload()
    model.showAvatar(Image(systemName: "person"), imageSize: nil, sourceFrame: .zero)
    #expect(model.photoDestination == nil)
  }

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

  @Test func commonFriendsOpenFromProfile() async throws {
    let friend = try Self.commonFriend()
    let details = try Self.otherProfile(friendship: .friends, commonFriends: [friend])
    var service = ProfileService()
    service.prepareDescription = { _ in nil }
    service.loadProfile = { _ in details }
    let model = try makeModel(service)
    await model.reload()
    model.showProfileFriends()
    #expect(model.navigationDestination == .commonFriends)
    #expect(model.sheetDestination == nil)
  }

  @Test func ownFriendsReloadOnEveryAppearanceAndReflectRemoval() async throws {
    let friend = try Self.commonFriend()
    let calls = Mutex(0)
    var service = ProfileService()
    service.loadFriends = {
      let count = calls.withLock { $0 += 1; return $0 }
      return count == 1 ? [friend] : []
    }
    let model = withDependencies {
      $0[ProfileService.self] = service
    } operation: {
      ProfileFriendsViewModel(friends: [friend], selection: .current)
    }
    await model.reload()
    expectNoDifference(model.friends.map(\.id), [friend.id])
    await model.reload()
    expectNoDifference(model.friends.count, 0)
    expectNoDifference(calls.withLock { $0 }, 2)
  }

  @Test func commonFriendsReloadForTheSelectedPerson() async throws {
    let friend = try Self.commonFriend()
    let hash = try UserAccessHash(String(repeating: "a", count: 256))
    var service = ProfileService()
    service.loadProfile = { selection in
      guard case let .other(id, accessHash) = selection else {
        Issue.record("Expected another user's profile")
        return nil
      }
      expectNoDifference(id, UserId(42))
      expectNoDifference(accessHash, hash)
      return try Self.otherProfile(friendship: .none, commonFriends: [])
    }
    let model = withDependencies {
      $0[ProfileService.self] = service
    } operation: {
      ProfileFriendsViewModel(friends: [friend], selection: .other(id: UserId(42), accessHash: hash))
    }
    await model.reload()
    expectNoDifference(model.friends.count, 0)
    #expect(!model.isOwn)
  }

  @Test func listRefreshFailureKeepsAlreadyDisplayedFriends() async throws {
    let friend = try Self.commonFriend()
    var service = ProfileService()
    service.loadFriends = { throw Failure.unavailable }
    let model = withDependencies {
      $0[ProfileService.self] = service
    } operation: {
      ProfileFriendsViewModel(friends: [friend], selection: .current)
    }
    await model.reload()
    expectNoDifference(model.friends.map(\.id), [friend.id])
    #expect(model.refreshFailed)
  }

  @Test(arguments: [false, true], [false, true])
  func newestFriendsRefreshWins(oldFails: Bool, ownProfile: Bool) async throws {
    let friend = try Self.commonFriend()
    let calls = Mutex(0)
    let (started, start) = AsyncStream<Void>.makeStream()
    let (resumed, resume) = AsyncStream<Void>.makeStream()
    let response = Task { for await _ in resumed { break } }
    var service = ProfileService()
    service.loadFriends = {
      let call = calls.withLock { $0 += 1; return $0 }
      if call > 1 { return [] }
      start.yield()
      await response.value
      if oldFails { throw Failure.unavailable }
      return [friend]
    }
    let model = withDependencies {
      $0[ProfileService.self] = service
    } operation: { ProfileFriendsViewModel(friends: [friend], selection: .current) }
    let profile = makeOwnModel(service)
    let reload = { if ownProfile { await profile.loadFriends() } else { await model.reload() } }
    let first = Task { await reload() }
    var iterator = started.makeAsyncIterator()
    _ = await iterator.next()
    await reload()
    resume.yield()
    resume.finish()
    await first.value
    expectNoDifference(ownProfile ? profile.displayedFriends?.count : model.friends.count, 0)
    #expect(ownProfile ? !profile.friendsRefreshFailed : !model.refreshFailed)
  }

  @Test func friendWithoutAvatarOpensTheCorrectProfile() throws {
    let friend = try Self.commonFriend()
    let model = ProfileFriendsViewModel(friends: [friend], selection: .current)
    model.showProfile(friend)
    guard case let .profile(id, accessHash) = model.destination else {
      Issue.record("Expected a profile destination")
      return
    }
    expectNoDifference(id, friend.id)
    expectNoDifference(accessHash, friend.accessHash)
  }

  @Test func removalOnlyAvailableForFriends() async throws {
    for status in [Friendship.none, .incomingRequest, .outgoingRequest, .outgoingDecline, .friends] {
      var service = ProfileService()
      service.prepareDescription = { _ in nil }
      let details = try Self.otherProfile(friendship: status)
      service.loadProfile = { _ in details }
      let model = try makeModel(service)
      await model.reload()
      let isFriend: Bool = if case .friends = status { true } else { false }
      expectNoDifference(model.enableRemoveFromFriends, isFriend)
    }
  }
}

private extension ProfileViewModelTests {
  private func makeOwnModel(_ service: ProfileService) -> ProfileViewModel {
    withDependencies {
      $0[ProfileService.self] = service
    } operation: {
      ProfileViewModel(mode: .selfProfile(.init(routeToSignUp: {})))
    }
  }

  private func makeModel(_ service: ProfileService) throws -> ProfileViewModel {
    let other = ProfileView.OtherProfile(id: UserId(1), accessHash: try UserAccessHash(String(repeating: "a", count: 256)))
    return withDependencies {
      $0[ProfileService.self] = service
    } operation: {
      ProfileViewModel(mode: .otherProfile(other))
    }
  }

  nonisolated private static func otherProfile(
    friendship: Friendship, commonFriends: [FriendSummary] = []
  ) throws -> LoadedProfile {
    let profile = ProfileInfo(avatarUrl: nil, nickname: try Nickname("Anna"),
      description: try UserDescription("Hello"), interests: [], socialUrl: nil, email: nil)
    return LoadedProfile(info: profile, relationship: .other(friendship: friendship, commonFriends: commonFriends))
  }

  nonisolated private static func commonFriend() throws -> FriendSummary {
    try FriendSummary(id: UserId(2), accessHash: UserAccessHash(String(repeating: "b", count: 256)),
                     nickname: Nickname("Maria"), avatarURL: nil)
  }
}

private enum Failure: Error { case unavailable }
