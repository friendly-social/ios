import CommunityFeature
import CommunityMarkdownService

extension CommunityFeedPreparationService {
  static var fixture: Self {
    Self(prepareExcerpt: { await MarkdownExcerpt.prepare(source: $0) })
  }
}
