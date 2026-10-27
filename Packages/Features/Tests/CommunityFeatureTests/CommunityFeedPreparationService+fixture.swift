import CommunityFeature
import CommunityMarkdownService

extension CommunityFeedPreparationService {
  static var fixture: Self {
    Self(prepareDocument: { await MarkdownDocument.prepare(source: $0) })
  }
}
