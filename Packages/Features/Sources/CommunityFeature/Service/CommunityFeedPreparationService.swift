import CommunityMarkdownService
import CommunityService
import DependenciesMacros

@DependencyClient
public struct CommunityFeedPreparationService: Sendable {
  public var prepareExcerpt: @Sendable (String) async -> MarkdownExcerpt? = { _ in nil }
}

extension CommunityFeedPreparationService {
  @concurrent
  func prepare(
    _ posts: [CommunityPost], reusing previous: [CommunityFeedPost]
  ) async throws -> [CommunityFeedPost] {
    let cached = Dictionary(previous.map { ($0.id, $0.content) }, uniquingKeysWith: { _, last in last })
    var result: [CommunityFeedPost] = []
    for post in posts {
      try Task.checkCancellation()
      if let content = cached[post.id], content.source == post.text,
         post.text == nil || content.excerpt != nil {
        result.append(CommunityFeedPost(post: post, content: content))
      } else {
        result.append(await preparePost(post))
      }
    }
    try Task.checkCancellation()
    return result
  }

  @concurrent
  func prepare(_ post: CommunityPost) async -> CommunityFeedPost {
    await preparePost(post)
  }
}

private extension CommunityFeedPreparationService {
  private func preparePost(_ post: CommunityPost) async -> CommunityFeedPost {
    let excerpt: MarkdownExcerpt?
    if let source = post.text {
      excerpt = await prepareExcerpt(source)
    } else {
      excerpt = nil
    }
    return CommunityFeedPost(post: post, content: .init(source: post.text, excerpt: excerpt))
  }
}
