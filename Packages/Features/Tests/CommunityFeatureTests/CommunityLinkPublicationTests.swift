@testable import CommunityFeature
import CommunityMarkdownService
import CustomDump
import Foundation
import Testing

@MainActor struct CommunityLinkPublicationTests {
  @Test func compactReplyKeepsItsTextFieldWhenURLIsEntered() async throws {
    let composer = makeComposerModel(service: .init(),
      drafts: .init(load: { nil }, save: { _ in }, remove: {}),
      replyTo: .init(id: 1, accessHash: "fixture"))
    await composer.restore()
    let address = "https://www.instagram.com/reel/Dera9yloYEM/?xtok=MXRkNHBvNGFzaWZheA=="
    let text = "Вот " + address
    composer.setPlainText(text)
    expectNoDifference(composer.plainText, text)
    expectNoDifference(try links(composer.editor.markdown), [URL(string: address)!])
    composer.stop()
  }

  @Test func namedLinkStillUsesRichReplyDraft() async {
    let composer = makeComposerModel(service: .init(),
      drafts: .init(load: { .init(content: "[Site](https://example.com)") }, save: { _ in }, remove: {}),
      replyTo: .init(id: 1, accessHash: "fixture"))
    await composer.restore()
    #expect(composer.plainText == nil)
    composer.stop()
  }
}

private extension CommunityLinkPublicationTests {
  private func links(_ source: String) throws -> [URL] {
    try MarkdownCodec().decode(source).runs.compactMap(\.link)
  }
}
