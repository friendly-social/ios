import CommunityMarkdownService
import CommunityService
import DependenciesMacros

@DependencyClient
public struct CommunityFeedPreparationService: Sendable {
  public var prepareDocument: @Sendable (String) async -> MarkdownDocument? = { _ in nil }
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
         post.text == nil || content.document != nil {
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
    let document: MarkdownDocument?
    if let source = post.text {
      document = await prepareDocument(source)
    } else {
      document = nil
    }
    return CommunityFeedPost(post: post, content: .init(source: post.text, document: document))
  }
}
