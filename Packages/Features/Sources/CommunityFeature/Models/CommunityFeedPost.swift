import CommunityMarkdownService
import CommunityService

struct CommunityFeedPost: Identifiable, Sendable {
  let post: CommunityPost
  let content: Content
  var id: Int64 { post.id }

  final class Content: Sendable {
    let source: String?
    let document: MarkdownDocument?

    var excerpt: MarkdownExcerpt? {
      document.map(MarkdownExcerpt.init)
    }

    init(source: String?, document: MarkdownDocument?) {
      self.source = source
      self.document = document
    }
  }
}
