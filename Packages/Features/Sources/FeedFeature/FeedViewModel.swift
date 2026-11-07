import Dependencies
import DiscoveryFeedService
import Foundation
import FriendlyUIKit
import Models
import Observation

@MainActor
@Observable
final class FeedViewModel {
  @ObservationIgnored @Dependency(DiscoveryFeedService.self) private var service

  var state: State = .loading
  var destination: Destination?

  func reload() async {
    do {
      try Task.checkCancellation()
      let candidates = try await service.loadCandidates()
      try Task.checkCancellation()
      state = .success(candidates.map(makeEntry))
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      state = .ioError
    }
  }

  enum State {
    case loading
    case ioError
    case success([Entry])

    enum Phase: Equatable { case loading, ioError, success }

    var phase: Phase {
      switch self {
      case .loading: .loading
      case .ioError: .ioError
      case .success: .success
      }
    }
  }

  enum Destination: Hashable, Identifiable {
    case friends(FriendsRoute)
    var id: Self { self }
  }

  struct FriendsRoute: Hashable {
    let id: UserId
    let accessHash: UserAccessHash
    let friends: [FriendSummary]

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
  }

  struct Entry {
    let id: UserId
    let avatarUrl: URL?
    let nickname: Nickname
    let description: UserDescription
    let interests: [Interest]
    let friendsPreview: FriendsPreview
    let onOpenFriends: () -> Void
    let isRequest: Bool
    let isExtendedNetwork: Bool
    let onLike: () -> Void
    let onDislike: () -> Void
  }
}

private extension FeedViewModel {
  private func makeEntry(_ candidate: DiscoveryCandidate) -> Entry {
    .init(
      id: candidate.id,
      avatarUrl: candidate.avatarURL,
      nickname: candidate.nickname,
      description: candidate.description,
      interests: candidate.interests,
      friendsPreview: FriendsPreview(friends: candidate.commonFriends),
      onOpenFriends: { [weak self] in
        self?.destination = .friends(.init(id: candidate.id, accessHash: candidate.accessHash,
                                          friends: candidate.commonFriends))
      },
      isRequest: candidate.isRequest,
      isExtendedNetwork: candidate.isExtendedNetwork,
      onLike: { [weak self] in self?.onLike(id: candidate.id, accessHash: candidate.accessHash) },
      onDislike: { [weak self] in self?.onDislike(id: candidate.id, accessHash: candidate.accessHash) }
    )
  }

  private func onLike(
    id: UserId,
    accessHash: UserAccessHash,
  ) {
    removeCandidate(id: id)
    Task {
      try? await service.requestFriend(id, accessHash)
    }
  }

  private func onDislike(
    id: UserId,
    accessHash: UserAccessHash,
  ) {
    removeCandidate(id: id)
    Task {
      try? await service.declineFriend(id, accessHash)
    }
  }

  // Failed actions stay dismissed until the next reload reconciles the queue.
  private func removeCandidate(id: UserId) {
    guard case .success(var entries) = state else {
      fatalError("Candidate actions require a loaded feed")
    }
    entries.removeAll { $0.id == id }
    state = .success(entries)
  }
}
