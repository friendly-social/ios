import CommunityMarkdownService
import CommunityService

struct CommunityFeedPost: Identifiable, Sendable {
  let post: CommunityPost
  let content: Content
  var id: Int64 { post.id }

  final class Content: Sendable {
    let source: String?
    let excerpt: MarkdownExcerpt?

    init(source: String?, excerpt: MarkdownExcerpt?) {
      self.source = source
      self.excerpt = excerpt
    }
  }
}
