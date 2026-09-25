import CommunityService
import Dependencies

extension CommunityService {
  public static func live() -> Self {
    let live = CommunityServiceLive()
    return .init(
      publish: { try await live.publish($0) },
      list: { try await live.list($0) },
      edit: { try await live.edit($0, $1) },
      delete: { try await live.delete($0) },
      reply: { try await live.reply($0, $1) },
      details: { try await live.details($0) },
      replies: { try await live.replies($0, $1) }
    )
  }
}

extension CommunityService: DependencyKey {
  public static var liveValue: Self { .live() }
}
