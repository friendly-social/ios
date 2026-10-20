import CommunityEditorFeature
import Foundation
import Testing

@MainActor
struct EditorPhotoIntegrationTests {
  @Test func photoMarkdownOpensInRichEditor() {
    let source = "**Before**\n\n![photo](https://example.com/photo.jpg)\n\nAfter"
    let model = CommunityEditorViewModel(source: source)
    #expect(!model.sourceOnly)
    #expect(model.markdown == source)
  }

  @Test func unfinishedPhotoDraftCannotBePublished() {
    let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let model = CommunityEditorViewModel(source: "![](friendly-photo://\(id))")
    #expect(!model.canPublish)
    #expect(model.markdown.contains(id.uuidString))
  }

  @Test func damagedLocalPhotoReferenceCannotBePublished() {
    let model = CommunityEditorViewModel(source: "![](friendly-photo://incomplete)")
    #expect(!model.canPublish)
  }
}
