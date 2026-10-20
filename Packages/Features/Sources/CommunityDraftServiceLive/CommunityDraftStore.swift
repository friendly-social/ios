import CommunityDraftService
import Foundation

actor CommunityDraftStore {
  private let directory: URL
  private var revokedSessions: Set<String> = []
  private var observers: [UUID: Observer] = [:]

  init(directory: URL) { self.directory = directory }

  func updates(accountID: Int64, sessionID: String) throws -> AsyncStream<String?> {
    let value = try load(accountID: accountID, sessionID: sessionID)?.content
    let id = UUID()
    let (stream, continuation) = AsyncStream<String?>.makeStream(bufferingPolicy: .bufferingNewest(1))
    observers[id] = Observer(accountID: accountID, sessionID: sessionID, continuation: continuation)
    continuation.yield(observedSource(value))
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeObserver(id) }
    }
    return stream
  }

  func load(accountID: Int64, sessionID: String) throws -> CommunityDraftSnapshot<String>? {
    try check(sessionID)
    guard let draft = try read(accountID) else { return nil }
    guard draft.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
    guard draft.sessionID == sessionID else { return nil }
    return .init(content: draft.markdown, cursor: draft.cursor)
  }

  func save(_ snapshot: CommunityDraftSnapshot<String>, accountID: Int64, sessionID: String) throws {
    try check(sessionID)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(Draft(sessionID: sessionID, markdown: snapshot.content, cursor: snapshot.cursor))
    try data.write(to: url(accountID), options: .atomic)
    notify(accountID: accountID, sessionID: sessionID, value: snapshot.content)
  }

  func loadReply(accountID: Int64, sessionID: String) throws -> CommunityDraftSnapshot<CommunityReplyDraft>? {
    try check(sessionID)
    let file = url(accountID)
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    let data = try Data(contentsOf: file)
    if let draft = try? JSONDecoder().decode(ReplyDraft.self, from: data) {
      guard draft.version == 2 else { throw CocoaError(.fileReadCorruptFile) }
      return draft.sessionID == sessionID ? .init(content: draft.content) : nil
    }
    let draft = try JSONDecoder().decode(Draft.self, from: data)
    guard draft.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
    return draft.sessionID == sessionID ? .init(content: .markdown(draft.markdown), cursor: draft.cursor) : nil
  }

  func remove(accountID: Int64, sessionID: String) throws {
    let file = url(accountID)
    guard FileManager.default.fileExists(atPath: file.path) else {
      notify(accountID: accountID, sessionID: sessionID, value: nil)
      return
    }
    let data = try Data(contentsOf: file)
    let owner = (try? JSONDecoder().decode(ReplyDraft.self, from: data))?.sessionID
      ?? (try? JSONDecoder().decode(Draft.self, from: data))?.sessionID
    guard owner == sessionID else { return }
    try FileManager.default.removeItem(at: url(accountID))
    notify(accountID: accountID, sessionID: sessionID, value: nil)
  }

  func revoke(accountID: Int64, sessionID: String) throws {
    revokedSessions.insert(sessionID)
    try remove(accountID: accountID, sessionID: sessionID)
  }

  private struct Draft: Codable {
    let version: Int
    let sessionID: String
    let markdown: String
    let cursor: Int?

    init(sessionID: String, markdown: String, cursor: Int? = nil) {
      self.version = 1
      self.sessionID = sessionID
      self.markdown = markdown
      self.cursor = cursor
    }

    init(from decoder: any Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      version = try values.decode(Int.self, forKey: .version)
      sessionID = try values.decode(String.self, forKey: .sessionID)
      markdown = try values.decode(String.self, forKey: .markdown)
      cursor = try? values.decode(Int.self, forKey: .cursor)
    }

    private enum CodingKeys: String, CodingKey {
      case version, sessionID, markdown, cursor
    }
  }

  private struct Observer {
    let accountID: Int64
    let sessionID: String
    let continuation: AsyncStream<String?>.Continuation
  }

  private struct ReplyDraft: Decodable {
    let version: Int
    let sessionID: String
    let content: CommunityReplyDraft
  }
}

private extension CommunityDraftStore {
  private func removeObserver(_ id: UUID) { observers[id] = nil }

  private func notify(accountID: Int64, sessionID: String, value: String?) {
    for observer in observers.values where observer.accountID == accountID {
      observer.continuation.yield(observer.sessionID == sessionID ? observedSource(value) : nil)
    }
  }

  private func observedSource(_ value: String?) -> String? {
    value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
  }

  private func check(_ sessionID: String) throws {
    if revokedSessions.contains(sessionID) { throw CancellationError() }
  }

  private func url(_ accountID: Int64) -> URL {
    directory.appending(component: "\(accountID)-new-post.json")
  }

  private func read(_ accountID: Int64) throws -> Draft? {
    let url = url(accountID)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(Draft.self, from: Data(contentsOf: url))
  }
}
