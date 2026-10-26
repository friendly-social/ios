struct CommunityDiscussionReply: Identifiable, Sendable {
  let id: Int64
  let rows: [CommunityFeedPost]

  init?(rows: [CommunityFeedPost]) {
    guard let first = rows.first else { return nil }
    id = first.id
    self.rows = rows
  }
}
