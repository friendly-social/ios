public import CommunityFeature
import CommunityMarkdownService
public import Dependencies

extension CommunityFeedPreparationService: DependencyKey {
  public static var liveValue: Self {
    .init(prepareExcerpt: { await MarkdownExcerpt.prepare(source: $0) })
  }
}
