import AccountStorageService
import CommunityApi
import CommunityService
import Dependencies

struct CommunityServiceLive: Sendable {
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(CommunityApi.self) private var api

  func publish(_ text: String) async throws -> PostDescriptor {
    try await perform { try await api.publish(text, nil, $0) }
  }

  func list(_ cursor: String?) async throws -> CommunityPage {
    try await perform { try await api.list(cursor, $0) }
  }

  func edit(_ id: Int64, _ text: String) async throws {
    try await perform { try await api.edit(id, text, $0) }
  }

  func delete(_ id: Int64) async throws {
    try await perform { try await api.delete(id, $0) }
  }

  func reply(_ parent: PostDescriptor, _ text: String) async throws -> PostDescriptor {
    try await perform { try await api.publish(text, parent, $0) }
  }

  func details(_ descriptor: PostDescriptor) async throws -> CommunityPostDetails {
    try await perform { try await api.details(descriptor, $0) }
  }

  func replies(_ descriptor: PostDescriptor, _ cursor: String) async throws -> CommunityReplyPage {
    try await perform { try await api.replies(descriptor, cursor, $0) }
  }
}

private extension CommunityServiceLive {
  private func perform<Value: Sendable>(
    _ operation: @Sendable (CommunityCredentials) async throws -> Value
  ) async throws -> Value {
    guard let authorization = try? storage.loadAuthorization() else {
      throw CommunityError.unauthorized
    }
    let credentials = CommunityCredentials(
      accountID: authorization.id.int64, token: authorization.token.string)
    let value = try await operation(credentials)
    guard let current = try? storage.loadAuthorization(),
          current.id == authorization.id,
          current.token == authorization.token else {
      throw CommunityError.unauthorized
    }
    return value
  }
}
