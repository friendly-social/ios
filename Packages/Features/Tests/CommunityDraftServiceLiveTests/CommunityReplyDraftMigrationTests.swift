import CommunityDraftService
@testable import CommunityDraftServiceLive
import CommunityService
import CustomDump
import Foundation
import Testing

@MainActor struct CommunityReplyDraftMigrationTests {
  @Test(arguments: [
    ("{\"plainText\":{\"_0\":\"*literal*\"}}", "\\*literal\\*"),
    ("{\"markdown\":{\"_0\":\"__bold__\"}}", "__bold__"),
  ])
  func unifiedComposerReadsLegacyDetailDraft(content: String, expected: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let folder = directory.appending(path: "Replies/42")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let data = Data("{\"version\":2,\"sessionID\":\"session\",\"content\":\(content)}".utf8)
    try data.write(to: folder.appending(component: "7-new-post.json"))
    let live = CommunityDraftServiceLive(directory: directory)
    let target = PostDescriptor(id: 42, accessHash: "parent")
    let restored = try await live.replyDrafts(target, 7, "session", { true }).load()
    expectNoDifference(restored?.content, expected)
    let anotherSession = try await live.replyDrafts(target, 7, "other", { true }).load()
    #expect(anotherSession == nil)
    try await live.replyDrafts(target, 7, "other", { true }).remove()
    #expect(FileManager.default.fileExists(atPath: folder.appending(component: "7-new-post.json").path))
  }

  @Test func savedReplyRetainsTheVersionOneFormat() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = CommunityDraftServiceLive(directory: directory)
    let target = PostDescriptor(id: 42, accessHash: "parent")
    try await live.replyDrafts(target, 7, "session", { true }).save(.init(content: "**Reply**", cursor: 3))
    let data = try Data(contentsOf: directory.appending(path: "Replies/42/7-new-post.json"))
    let oldReader = try JSONDecoder().decode(VersionOneDraft.self, from: data)
    expectNoDifference(oldReader.version, 1)
    expectNoDifference(oldReader.sessionID, "session")
    expectNoDifference(oldReader.markdown, "**Reply**")
  }
}

private struct VersionOneDraft: Decodable {
  let version: Int
  let sessionID: String
  let markdown: String
}
