import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
public final class ActivityDiscussionViewModel {
  public private(set) var discussion: ActivityDiscussion?
  public private(set) var isLoading = false
  public private(set) var error: LocalizedStringResource?
  @ObservationIgnored @Dependency(ActivityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profile
  private let event: ActivityEvent
  private let session: CommunitySession
  private let onUnauthorized: () -> Void
  private let onRead: () -> Void

  public init(
    event: ActivityEvent, session: CommunitySession,
    onUnauthorized: @escaping () -> Void, onRead: @escaping () -> Void
  ) {
    self.event = event
    self.session = session
    self.onUnauthorized = onUnauthorized
    self.onRead = onRead
  }

  public func load() async {
    guard discussion == nil, !isLoading, acceptsSession else { return }
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
      let result = try await openDiscussion()
      guard acceptsSession else { return }
      discussion = result
    } catch {
      handle(error) {
        self.error = error as? ActivityError == .unavailable
          || error as? CommunityError == .rejected(404)
          ? .activityDiscussionUnavailable : .activityDiscussionLoadError
      }
      return
    }
    await markRead()
  }
}

private extension ActivityDiscussionViewModel {
  private func openDiscussion() async throws -> ActivityDiscussion {
    switch event.content {
    case let .reply(post): try await service.openReply(post.descriptor, session)
    case let .indirectReplies(_, commonDenominator):
      try await service.openThread(commonDenominator, session)
    case .friendRequest, .friendRequestAccepted: throw ActivityError.unavailable
    }
  }

  private var acceptsSession: Bool {
    profile.isCurrentSession(session) && !Task.isCancelled
  }

  private func markRead() async {
    guard !event.isRead, acceptsSession else { return }
    do {
      try await service.markRead(event.id, session)
      guard acceptsSession else { return }
      onRead()
    } catch { handle(error) {} }
  }

  private func handle(_ error: any Error, fallback: () -> Void) {
    guard acceptsSession, !(error is CancellationError) else { return }
    if error as? CommunityError == .unauthorized {
      profile.clearSession()
      onUnauthorized()
    } else { fallback() }
  }
}
