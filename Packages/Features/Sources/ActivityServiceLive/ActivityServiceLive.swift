import ActivityApi
import ActivityService
import CommunityApi
import CommunityProfileService
import CommunityService
import Dependencies

struct ActivityServiceLive: Sendable {
  @Dependency(ActivityApi.self) private var api
  @Dependency(CommunityApi.self) private var community
  @Dependency(CommunityProfileService.self) private var profile

  func list(_ cursor: String?, session: CommunitySession) async throws -> ActivityPage {
    try validate(session)
    let result = try await api.list(cursor, credentials(session))
    try validate(session)
    return .init(events: result.events.map {
      .init(id: $0.id, date: $0.date, isRead: $0.isRead, content: $0.content,
            preview: ActivityPreview.text($0.post?.text ?? ""))
    }, nextID: result.nextID)
  }

  func hasNewUnreads(session: CommunitySession) async throws -> Bool {
    try validate(session)
    let result = try await api.hasNewUnreads(credentials(session))
    try validate(session)
    return result
  }

  func acknowledgeUnreads(session: CommunitySession) async throws {
    try validate(session)
    try await api.acknowledgeUnreads(credentials(session))
    try validate(session)
  }

  func markRead(_ id: Int64, session: CommunitySession) async throws {
    try validate(session)
    try await api.markRead(id, credentials(session))
    try validate(session)
  }

  func openThread(_ descriptor: PostDescriptor, session: CommunitySession) async throws -> ActivityDiscussion {
    try validate(session)
    let credentials = CommunityCredentials(accountID: session.accountID, token: session.token)
    let details = try await community.details(descriptor, credentials)
    try validate(session)
    return .init(details: details, replyID: nil)
  }

  func openReply(_ descriptor: PostDescriptor, session: CommunitySession) async throws -> ActivityDiscussion {
    try validate(session)
    let credentials = CommunityCredentials(accountID: session.accountID, token: session.token)
    let reply = try await community.details(descriptor, credentials)
    try validate(session)
    guard case .published = reply.post, let parent = reply.upstream.last else {
      throw ActivityError.unavailable
    }
    let details = try await community.details(parent.descriptor, credentials)
    try validate(session)
    let replies = try await findReply(reply.post, in: details, credentials: credentials, session: session)
    return .init(details: .init(post: details.post, upstream: details.upstream, replies: replies), replyID: reply.post.id)
  }
}

private extension ActivityServiceLive {
  private func findReply(
    _ target: CommunityPost, in details: CommunityPostDetails,
    credentials: CommunityCredentials, session: CommunitySession
  ) async throws -> CommunityReplyPage {
    var items = details.replies.data
    var cursor = details.replies.nextId
    var visited: Set<String> = []
    while !items.contains(where: { $0.directPost?.id == target.id }), let next = cursor {
      guard visited.insert(next).inserted else { throw ActivityError.invalidResponse }
      try Task.checkCancellation()
      let page = try await community.replies(details.post.descriptor, next, credentials)
      try validate(session)
      items += page.data
      cursor = page.nextId
    }
    // Older servers omit reply cursors; the separately fetched reply still belongs to this parent.
    if !items.contains(where: { $0.directPost?.id == target.id }) { items.append(.single(target)) }
    return .init(data: items, nextId: cursor)
  }

  private func validate(_ session: CommunitySession) throws {
    try Task.checkCancellation()
    guard profile.isCurrentSession(session) else { throw CommunityError.unauthorized }
  }

  private func credentials(_ session: CommunitySession) -> ActivityCredentials {
    .init(accountID: session.accountID, token: session.token)
  }
}
