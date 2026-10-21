@testable import CommunityEditorFeature
import CommunityMarkdownService
import CustomDump
import Foundation
import Testing
import UIKit

@MainActor struct EditorLinkSerializationTests {
  @Test func typingPlainURLProducesClickableMarkdownWithoutChangingURL() throws {
    let editor = makeEditor("")
    let address = "https://www.instagram.com/reel/Dera9yloYEM/?xtok=MXRkNHBvNGFzaWZheA=="
    editor.view.insertText(address)
    editor.model.refresh()
    let decoded = try MarkdownCodec().decode(editor.model.markdown)
    expectNoDifference(String(decoded.characters), address)
    expectNoDifference(decoded.runs.compactMap(\.link), [URL(string: address)!])
    editor.model.detach()
  }

  @Test func photoDoesNotChangeAdjacentURLDestination() throws {
    let address = "https://www.instagram.com/reel/Dera9yloYEM/?xtok=MXRkNHBvNGFzaWZheA=="
    let photo = PhotoAttachment(id: UUID(), sourceID: UUID(),
      sourceURL: URL(string: "https://example.com/photo.jpg")!, preview: nil)
    let content = NSMutableAttributedString(string: address + "\n\n")
    content.append(NSAttributedString(attachment: photo))
    let source = PhotoMarkdownCodec.encode(content)
    let decoded = try MarkdownCodec().decode(String(source.prefix(while: { $0 != "\n" })))
    expectNoDifference(decoded.runs.compactMap(\.link), [URL(string: address)!])
  }
}
