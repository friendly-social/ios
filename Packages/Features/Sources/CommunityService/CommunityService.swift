import DependenciesMacros
import Foundation

@DependencyClient
public struct CommunityService: Sendable {
  public var publish: @Sendable (String) async throws -> PostDescriptor
  public var list: @Sendable (String?) async throws -> CommunityPage
  public var edit: @Sendable (Int64, String) async throws -> Void = { _, _ in throw CommunityError.unavailable }
  public var delete: @Sendable (Int64) async throws -> Void = { _ in throw CommunityError.unavailable }
  public var reply: @Sendable (PostDescriptor, String) async throws -> PostDescriptor = { _, _ in throw CommunityError.unavailable }
  public var details: @Sendable (PostDescriptor) async throws -> CommunityPostDetails = { _ in throw CommunityError.unavailable }
  public var replies: @Sendable (PostDescriptor, String) async throws -> CommunityReplyPage = { _, _ in throw CommunityError.unavailable }
}

public struct PostDescriptor: Codable, Sendable, Hashable {
  public let id: Int64
  public let accessHash: String

  public init(id: Int64, accessHash: String) {
    self.id = id
    self.accessHash = accessHash
  }
}

public enum CommunityPost: Sendable, Equatable, Identifiable {
  case published(PublishedPost)
  case deleted(DeletedPost)
  case awaitingDetails(NewlyPublishedPost)

  public struct Owner: Sendable, Equatable {
    public let nickname: String
    public let id: Int64
    public let accessHash: String
    public let avatar: Avatar?

    public init(id: Int64, accessHash: String, nickname: String, avatar: Avatar? = nil) {
      self.id = id
      self.accessHash = accessHash
      self.nickname = nickname
      self.avatar = avatar
    }

    public struct Avatar: Sendable, Equatable {
      public let id: Int64
      public let accessHash: String

      public init(id: Int64, accessHash: String) {
        self.id = id
        self.accessHash = accessHash
      }
    }
  }

  public struct PublishedPost: Sendable, Equatable {
    public let descriptor: PostDescriptor
    public var text: String
    public let owner: Owner
    public let date: Date
    public var edited: Bool
    public let replyPreviews: [Owner]

    public init(descriptor: PostDescriptor, text: String, owner: Owner, date: Date, edited: Bool, replyPreviews: [Owner] = []) {
      self.descriptor = descriptor
      self.text = text
      self.owner = owner
      self.date = date
      self.edited = edited
      self.replyPreviews = replyPreviews
    }
  }

  public struct DeletedPost: Sendable, Equatable {
    public let descriptor: PostDescriptor
    public let date: Date
    public let replyPreviews: [Owner]

    public init(descriptor: PostDescriptor, date: Date, replyPreviews: [Owner] = []) {
      self.descriptor = descriptor
      self.date = date
      self.replyPreviews = replyPreviews
    }
  }

  public struct NewlyPublishedPost: Sendable, Equatable {
    public let descriptor: PostDescriptor
    public var text: String
    public var edited: Bool
    public let owner: Owner?
    public let date: Date?

    public init(
      descriptor: PostDescriptor, text: String, edited: Bool = false,
      owner: Owner? = nil, date: Date? = nil
    ) {
      self.descriptor = descriptor
      self.text = text
      self.edited = edited
      self.owner = owner
      self.date = date
    }
  }

  public var descriptor: PostDescriptor {
    switch self {
    case let .published(post): post.descriptor
    case let .deleted(post): post.descriptor
    case let .awaitingDetails(post): post.descriptor
    }
  }

  public var id: Int64 { descriptor.id }
  public var accessHash: String { descriptor.accessHash }

  public var replyPreviews: [Owner] {
    switch self {
    case let .published(post): post.replyPreviews
    case let .deleted(post): post.replyPreviews
    case .awaitingDetails: []
    }
  }

  public var text: String? {
    switch self {
    case let .published(post): post.text
    case let .awaitingDetails(post): post.text
    case .deleted: nil
    }
  }

  public var owner: Owner? {
    switch self {
    case let .published(post): post.owner
    case let .awaitingDetails(post): post.owner
    case .deleted: nil
    }
  }

  public var date: Date? {
    switch self {
    case let .published(post): post.date
    case let .deleted(post): post.date
    case let .awaitingDetails(post): post.date
    }
  }

  public var edited: Bool {
    switch self {
    case let .published(post): post.edited
    case let .awaitingDetails(post): post.edited
    case .deleted: false
    }
  }

  public func replacingText(_ text: String) -> Self {
    switch self {
    case .published(var post):
      post.text = text
      post.edited = true
      return .published(post)
    case .awaitingDetails(var post):
      post.text = text
      post.edited = true
      return .awaitingDetails(post)
    case .deleted:
      return self
    }
  }
}

public struct CommunityPage: Sendable, Equatable {
  public let data: [CommunityPost]
  public let nextId: String?

  public init(data: [CommunityPost], nextId: String?) {
    self.data = data
    self.nextId = nextId
  }
}

public enum CommunityReply: Sendable, Equatable {
  case single(CommunityPost)
  case thread([CommunityPost])

  public var directPost: CommunityPost? {
    switch self {
    case let .single(post): post
    case let .thread(posts): posts.first
    }
  }
}

public struct CommunityReplyPage: Sendable, Equatable {
  public let data: [CommunityReply]
  public let nextId: String?

  public init(data: [CommunityReply], nextId: String?) {
    self.data = data
    self.nextId = nextId
  }
}

public struct CommunityPostDetails: Sendable, Equatable {
  public let post: CommunityPost
  public let upstream: [CommunityPost]
  public let replies: CommunityReplyPage

  public init(post: CommunityPost, upstream: [CommunityPost], replies: CommunityReplyPage) {
    self.post = post
    self.upstream = upstream
    self.replies = replies
  }
}

public enum CommunityError: Error, Equatable {
  case unauthorized
  case rejected(Int)
  case outcomeUnknown
  case unavailable
}
