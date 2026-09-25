import CommunityApi
import Dependencies

extension CommunityApi {
  public static func live() -> Self {
    let live = CommunityApiLive()
    return .init(
      publish: { try await live.publish($0, replyTo: $1, credentials: $2) },
      edit: { try await live.edit(id: $0, text: $1, credentials: $2) },
      delete: { try await live.delete(id: $0, credentials: $1) },
      list: { try await live.list(cursor: $0, credentials: $1) },
      details: { try await live.details($0, credentials: $1) },
      replies: { try await live.replies(to: $0, cursor: $1, credentials: $2) }
    )
  }
}

extension CommunityApi: DependencyKey {
  public static var liveValue: Self { .live() }
}
