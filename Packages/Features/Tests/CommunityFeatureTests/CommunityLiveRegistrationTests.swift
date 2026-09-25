import CommunityDraftService
import CommunityDraftServiceLive
import Dependencies
import Testing

@Test
func communityLiveRegistrationResolvesThroughInterface() async throws {
  let draft = try await withDependencies {
    $0.context = .live
  } operation: {
    @Dependency(CommunityDraftService.self) var services
    let drafts = services.postDrafts(-9_999_999, "registration-check", { true })
    return try await drafts.load()
  }
  #expect(draft == nil)
}
