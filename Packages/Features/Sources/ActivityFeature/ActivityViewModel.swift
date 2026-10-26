import ActivityService
import CommunityProfileService
import CommunityService
import Dependencies
import Foundation
import Observation

@MainActor @Observable
public final class ActivityViewModel {
  public private(set) var events: [ActivityEvent] = []
  public private(set) var isLoading = false
  public private(set) var isLoadingMore = false
  public private(set) var nextID: String?
  public private(set) var error: LocalizedStringResource?
  public private(set) var pageError: LocalizedStringResource?
  public var discussion: ActivityReplyDestination?
  @ObservationIgnored @Dependency(ActivityService.self) private var service
  @ObservationIgnored @Dependency(CommunityProfileService.self) private var profile
  @ObservationIgnored @Dependency(\.date.now) private var now
  private var session: CommunitySession?
  private var generation = 0
  private var hasLoaded = false
  private var readIDs: Set<Int64> = []
  private let onUnauthorized: () -> Void

  public init(onUnauthorized: @escaping () -> Void) {
    self.onUnauthorized = onUnauthorized
  }

  public func start() async {
    guard let current = profile.currentSession() else { onUnauthorized(); return }
    if session != current { reset(for: current) }
    if !hasLoaded { await load() }
    else if let session { await acknowledgeUnreads(session) }
  }

  public func load() async {
    guard let session, profile.isCurrentSession(session), !isLoading else { return }
    generation += 1
    let request = generation
    isLoading = true
    isLoadingMore = false
    error = nil
    pageError = nil
    defer { if generation == request { isLoading = false } }
    do {
      let page = try await service.list(nil, session)
      guard accepts(session, generation: request) else { return }
      events = merged(page.events)
      nextID = page.nextID
      hasLoaded = true
      isLoading = false
      await acknowledgeUnreads(session)
    } catch {
      guard generation == request else { return }
      handle(error, session: session) { self.error = .activityLoadError }
    }
  }

  public func loadMore() async {
    guard let session, profile.isCurrentSession(session), let cursor = nextID,
          !isLoading, !isLoadingMore else { return }
    let request = generation
    isLoadingMore = true
    pageError = nil
    defer { if generation == request { isLoadingMore = false } }
    do {
      let page = try await service.list(cursor, session)
      guard accepts(session, generation: request) else { return }
      events = merged(events + page.events)
      nextID = page.nextID == cursor ? nil : page.nextID
    } catch {
      guard generation == request else { return }
      handle(error, session: session) { self.pageError = .activityLoadError }
    }
  }

  public func openButtonTapped(_ event: ActivityEvent) {
    guard let session, profile.isCurrentSession(session), discussion == nil else { return }
    discussion = ActivityReplyDestination(event: event, session: session)
  }

  public func didRead(_ id: Int64, session: CommunitySession) {
    guard self.session == session, profile.isCurrentSession(session) else { return }
    readIDs.insert(id)
    if let index = events.firstIndex(where: { $0.id == id }) { events[index].isRead = true }
  }

  public func avatarURL(for event: ActivityEvent) -> URL? {
    event.owner?.avatar.map(profile.avatarURL)
  }

  func events(in group: ActivityTimeGroup) -> [ActivityEvent] {
    events.filter { timeGroup(for: $0.date) == group }
  }
}

private extension ActivityViewModel {
  private func acknowledgeUnreads(_ session: CommunitySession) async {
    guard profile.isCurrentSession(session), !Task.isCancelled else { return }
    do {
      try await service.acknowledgeUnreads(session)
    } catch {
      handle(error, session: session) {}
    }
  }

  private func merged(_ source: [ActivityEvent]) -> [ActivityEvent] {
    var seen: Set<Int64> = []
    return source.compactMap { event in
      guard seen.insert(event.id).inserted else { return nil }
      var event = event
      if readIDs.contains(event.id) { event.isRead = true }
      return event
    }.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
  }

  private func accepts(_ session: CommunitySession, generation: Int) -> Bool {
    self.generation == generation && profile.isCurrentSession(session) && !Task.isCancelled
  }

  private func handle(_ error: any Error, session: CommunitySession, fallback: () -> Void) {
    guard profile.isCurrentSession(session), !Task.isCancelled, !(error is CancellationError) else { return }
    if error as? CommunityError == .unauthorized {
      profile.clearSession()
      onUnauthorized()
    } else { fallback() }
  }

  private func reset(for session: CommunitySession) {
    self.session = session
    events = []
    readIDs = []
    nextID = nil
    discussion = nil
    hasLoaded = false
    generation += 1
    isLoading = false
    isLoadingMore = false
    error = nil
    pageError = nil
  }

  private func timeGroup(for date: Date) -> ActivityTimeGroup {
    let calendar = Calendar.current
    if calendar.isDate(date, inSameDayAs: now) { return .today }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
       calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
    return .older
  }
}

enum ActivityTimeGroup: CaseIterable, Identifiable {
  case today, yesterday, older
  var id: Self { self }
}
