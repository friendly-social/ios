public import CommunityFeature
import CommunityMarkdownService
public import Dependencies

extension CommunityFeedPreparationService: DependencyKey {
  public static var liveValue: Self {
    .init(prepareDocument: { await MarkdownDocument.prepare(source: $0) })
  }
}
