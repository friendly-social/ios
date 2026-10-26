import ActivityService
import ActivityServiceLive
import CommunityApi
import CommunityProfileService
import CommunityService
import CustomDump
import Dependencies
import Foundation
import Testing

struct ActivityDiscussionTests {
  @Test func opensIndirectActivityAtThreadRootWithoutRequiringAParent() async throws {
    let service = liveService(details: { descriptor, _ in details(post(descriptor.id), replies: [post(3)]) })
    let result = try await service.openThread(post(1).descriptor, session)
    expectNoDifference(result.details.post.id, 1)
    #expect(result.replyID == nil)
  }

  @Test func opensOurParentWithAncestorsAndReceivedReplyBelowIt() async throws {
    let root = post(1, owner: 9)
    let ours = post(2, owner: 7)
    let reply = post(3, owner: 8)
    let ledger = RequestLedger()
    let service = liveService(details: { descriptor, _ in
      await ledger.record(descriptor.id)
      if descriptor.id == reply.id {
        return details(reply, ancestors: [root, ours])
      }
      return details(ours, ancestors: [root], replies: [reply])
    })
    let result = try await service.openReply(reply.descriptor, session)
    #expect(result.details.post.id == ours.id)
    #expect(result.details.upstream.map(\.id) == [root.id])
    #expect(result.details.replies.data.compactMap(\.directPost).map(\.id) == [reply.id])
    #expect(result.replyID == reply.id)
    #expect(await ledger.ids == [reply.id, ours.id])
  }

  @Test func findsDirectReplyOnLaterPageEvenWhenItStartsAThread() async throws {
    let ours = post(2)
    let reply = post(30, owner: 8)
    let ledger = RequestLedger()
    let service = liveService(details: { descriptor, _ in
      if descriptor.id == reply.id { return details(reply, ancestors: [ours]) }
      return details(ours, replies: [post(3)], next: "cursor")
    }, replies: { descriptor, cursor, _ in
      #expect(descriptor == ours.descriptor)
      #expect(cursor == "cursor")
      await ledger.record(descriptor.id)
      return .init(data: [.thread([reply, post(31)])], nextId: "next")
    })
    let result = try await service.openReply(reply.descriptor, session)
    #expect(result.details.replies.data.compactMap(\.directPost).map(\.id) == [3, 30])
    #expect(result.details.replies.nextId == "next")
    #expect(await ledger.ids == [2])
  }

  @Test func preservesReplyWhenServerOmitsPaginationCursor() async throws {
    let ours = post(2)
    let reply = post(30, owner: 8)
    let service = liveService(details: { descriptor, _ in
      descriptor.id == reply.id ? details(reply, ancestors: [ours]) : details(ours, replies: [post(3)])
    })
    let result = try await service.openReply(reply.descriptor, session)
    #expect(result.details.post.id == ours.id)
    #expect(result.details.replies.data.compactMap(\.directPost).map(\.id) == [3, 30])
  }

  @Test func deletedParentKeepsItsPlaceInTheChain() async throws {
    let ours = CommunityPost.deleted(.init(descriptor: post(2).descriptor, date: .now))
    let reply = post(3, owner: 8)
    let service = liveService(details: { descriptor, _ in
      descriptor.id == reply.id ? details(reply, ancestors: [post(1), ours])
        : details(ours, ancestors: [post(1)], replies: [reply])
    })
    let result = try await service.openReply(reply.descriptor, session)
    #expect(result.details.post == ours)
    #expect(result.details.upstream.map(\.id) == [1])
  }

  @Test func missingParentDoesNotOpenReplyAsMainMessage() async throws {
    let service = liveService(details: { descriptor, _ in details(post(descriptor.id)) })
    await #expect(throws: ActivityError.unavailable) {
      try await service.openReply(post(3).descriptor, session)
    }
  }

  @Test func repeatedPaginationCursorDoesNotLoopForever() async throws {
    let service = liveService(details: { descriptor, _ in
      descriptor.id == 30 ? details(post(30), ancestors: [post(2)]) : details(post(2), next: "same")
    }, replies: { _, _, _ in .init(data: [], nextId: "same") })
    await #expect(throws: ActivityError.invalidResponse) {
      try await service.openReply(post(30).descriptor, session)
    }
  }
}

private extension ActivityDiscussionTests {
  private var session: CommunitySession { .init(accountID: 7, token: "token", sessionID: "session") }

  private func liveService(
    details: @escaping @Sendable (PostDescriptor, CommunityCredentials) async throws -> CommunityPostDetails,
    replies: @escaping @Sendable (PostDescriptor, String, CommunityCredentials) async throws -> CommunityReplyPage = {
      _, _, _ in .init(data: [], nextId: nil)
    }
  ) -> ActivityService {
    var community = CommunityApi()
    community.details = details
    community.replies = replies
    var profile = CommunityProfileService()
    profile.isCurrentSession = { _ in true }
    return withDependencies {
      $0[CommunityApi.self] = community
      $0[CommunityProfileService.self] = profile
    } operation: { ActivityService.live() }
  }
}

private func post(_ id: Int64, owner: Int64 = 7) -> CommunityPost {
  .published(.init(descriptor: .init(id: id, accessHash: "hash-\(id)"), text: "Post \(id)",
                   owner: .init(id: owner, accessHash: "user", nickname: "Author"),
                   date: .init(timeIntervalSince1970: Double(id)), edited: false))
}

private func details(
  _ post: CommunityPost, ancestors: [CommunityPost] = [],
  replies: [CommunityPost] = [], next: String? = nil
) -> CommunityPostDetails {
  .init(post: post, upstream: ancestors, replies: .init(data: replies.map(CommunityReply.single), nextId: next))
}

private actor RequestLedger {
  var ids: [Int64] = []
  func record(_ id: Int64) { ids.append(id) }
}
