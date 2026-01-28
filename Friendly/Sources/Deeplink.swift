import Foundation

enum Deeplink {
    case addFriend(id: UserId, token: FriendToken)

    static let addFriend: Regex<(Substring, Substring, Substring)> =
        try! Regex("friendly://add/(.*)/(.*)")

    static func of(url: URL) -> Deeplink? {
        if let match = try! addFriend.wholeMatch(in: url.absoluteString) {
            let rawId = String(match.output.1)
            let rawToken = String(match.output.2)
            guard let idInt64 = Int64(rawId) else { return nil }
            let id = UserId(idInt64)
            guard let token = try? FriendToken(rawToken) else { return nil }
            return .addFriend(id: id, token: token)
        }
        return nil
    }
}
