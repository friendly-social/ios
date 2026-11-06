import Foundation
import Models
import Testing

struct InvitationLinkTests {
  @Test func createsAndParsesCanonicalInvitationURL() throws {
    let token = FriendToken("Abcdef012345-._~")
    let url = try Deeplink.invitationURL(for: token)
    #expect(url.absoluteString == "https://invite.getfriend.ly/Abcdef012345-._~")
    guard case let .addFriend(parsed)? = Deeplink.parseOf(url: url) else {
      Issue.record("Generated invitation URL was not recognized")
      return
    }
    #expect(parsed == token)
  }

  @Test func parsesFriendlyDeepLinkWithTokenOnly() throws {
    let token = "EpFXxdJTBD82MGAy"
    let url = try #require(URL(string: "friendly://add/\(token)"))
    guard case let .addFriend(found)? = Deeplink.parseOf(url: url) else {
      Issue.record("Friendly deep link was not recognized")
      return
    }
    #expect(found.string == token)
  }

  @Test(arguments: [
    "https://getfriend.ly/EpFXxdJTBD82MGAy",
    "https://getfriend.ly/#?invite=EpFXxdJTBD82MGAy",
    "https://getfriend.ly/?reference=add/123/EpFXxdJTBD82MGAy",
    "https://getfriend.ly/#?reference=add/123/EpFXxdJTBD82MGAy",
    "https://friendly-social.github.io/landing/#/?reference=add%2F123%2FEpFXxdJTBD82MGAy",
    "https://example.org/?reference=add/123/EpFXxdJTBD82MGAy",
    "friendly://add/123/EpFXxdJTBD82MGAy",
  ])
  func rejectsOldInvitationFormats(_ link: String) throws {
    let url = try #require(URL(string: link))
    #expect(Deeplink.parseOf(url: url) == nil)
  }

  @Test func preservesTokenWithoutClientValidation() throws {
    let token = FriendToken("new+токен/more")
    let url = try Deeplink.invitationURL(for: token)
    #expect(url.absoluteString.contains("new%2B"))
    #expect(url.absoluteString.contains("%2Fmore"))
    guard case let .addFriend(parsed)? = Deeplink.parseOf(url: url) else {
      Issue.record("Generated invitation URL was not recognized")
      return
    }
    #expect(parsed == token)
  }

  @Test func rejectsMissingTokensAndOtherHosts() throws {
    let links = [
      "https://example.org/EpFXxdJTBD82MGAy",
      "https://example.org/#?invite=EpFXxdJTBD82MGAy",
      "https://getfriend.ly/#?invite=",
      "https://invite.getfriend.ly/",
      "https://invite.getfriend.ly/one/two",
      "friendly://add/",
      "friendly://add/not-an-id/EpFXxdJTBD82MGAy",
      "https://invite.getfriend.ly.example.org/EpFXxdJTBD82MGAy",
    ]
    for link in links {
      let url = try #require(URL(string: link))
      #expect(Deeplink.parseOf(url: url) == nil)
    }
  }
}
