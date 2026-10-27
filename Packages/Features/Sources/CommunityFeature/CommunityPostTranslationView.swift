import SwiftUI

struct CommunityPostTranslationView<Content: View>: View {
  let original: CommunityFeedPost.Content
  let allowsTranslation: Bool
  @ViewBuilder let content: (CommunityFeedPost.Content, CommunityPostTranslationViewModel?) -> Content
  @State private var model = CommunityPostTranslationViewModel()

  var body: some View { contentView() }
}

private extension CommunityPostTranslationView {
  @ViewBuilder
  private func contentView() -> some View {
    if allowsTranslation { translatedContentView() }
    else { content(original, nil) }
  }

  private func translatedContentView() -> some View {
    content(displayedContent, model)
      .task(id: ObjectIdentifier(original)) { await model.load(original) }
      .task(id: model.requestID) {
        if let id = model.requestID { await model.translateRequested(id) }
      }
      .task(id: model.requestID) {
        if let id = model.requestID { await model.waitForTranslation(id) }
      }
      .onDisappear { model.stop() }
  }

  private var displayedContent: CommunityFeedPost.Content {
    guard let content = model.content, content.source == original.source else { return original }
    return content
  }
}
