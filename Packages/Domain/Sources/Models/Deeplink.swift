import Foundation

public enum Deeplink {
  case addFriend(token: FriendToken)
}

extension Deeplink {
  public static func invitationURL(for token: FriendToken) throws -> URL {
    guard let pathSegment = token.string.addingPercentEncoding(withAllowedCharacters: Constants.pathSegmentCharacters) else {
      throw URLError(.badURL)
    }
    var components = URLComponents()
    components.scheme = Constants.scheme
    components.host = Constants.inviteHost
    components.percentEncodedPath = "/\(pathSegment)"
    guard let url = components.url else { throw URLError(.badURL) }
    return url
  }

  public static func parseOf(url: URL) -> Deeplink? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.user == nil, components.password == nil, components.port == nil,
          components.query == nil, components.fragment == nil,
          components.percentEncodedPath.hasPrefix("/") else { return nil }
    let pathSegment = components.percentEncodedPath.dropFirst()
    guard !pathSegment.contains("/"),
          let rawToken = pathSegment.removingPercentEncoding,
          !rawToken.isEmpty else { return nil }
    switch (components.scheme?.lowercased(), components.host?.lowercased()) {
    case (Constants.scheme, Constants.inviteHost), (Constants.appScheme, Constants.addHost):
      return .addFriend(token: FriendToken(rawToken))
    default:
      return nil
    }
  }
}

private enum Constants {
  static let scheme = "https"
  static let inviteHost = "invite.getfriend.ly"
  static let appScheme = "friendly"
  static let addHost = "add"
  static let pathSegmentCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  )
}
