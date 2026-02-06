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

extension Deeplink {
    // friendly://add/<id>/<token>
    private static let friendlyRegex: Regex<(Substring, Substring, Substring)> =
        try! Regex(#"^friendly://add/([^/]+)/(.+)$"#)

    // add/<id>/<token>
    private static let referenceRegex: Regex<(Substring, Substring, Substring)> =
        try! Regex(#"^add/([^/]+)/(.+)$"#)

    static func parseOf(url: URL) -> Deeplink? {
        if let deeplink = parseFriendly(url: url) { return deeplink }
        if let deeplink = parseReferenceURL(url: url) { return deeplink }
        return nil
    }
}

private extension Deeplink {
    static func parseFriendly(url: URL) -> Deeplink? {
        guard url.scheme?.lowercased() == "friendly" else { return nil }

        let string = url.absoluteString
        guard let match = try? friendlyRegex.wholeMatch(in: string) else { return nil }

        let rawId = String(match.output.1)
        let rawToken = String(match.output.2)
        return makeAddFriend(rawId: rawId, rawToken: rawToken)
    }

    static func parseReferenceURL(url: URL) -> Deeplink? {
        if let reference = url.queryValue("reference"),
           let deeplink = parseReference(reference) {
            return deeplink
        }

        if let fragment = url.fragment,
           let reference = extractReference(from: fragment),
           let deeplink = parseReference(reference) {
            return deeplink
        }

        return nil
    }

    static func parseReference(_ reference: String) -> Deeplink? {
        let decoded = reference.removingPercentEncoding ?? reference
        guard let match = try? referenceRegex.wholeMatch(in: decoded) else { return nil }

        let rawId = String(match.output.1)
        let rawToken = String(match.output.2)
        return makeAddFriend(rawId: rawId, rawToken: rawToken)
    }

    static func extractReference(from fragment: String) -> String? {
        let decoded = fragment.removingPercentEncoding ?? fragment
        guard let range = decoded.range(of: "reference=") else { return nil }

        let tail = decoded[range.upperBound...]
        if let amp = tail.firstIndex(of: "&") {
            return String(tail[..<amp])
        }
        return String(tail)
    }

    static func makeAddFriend(rawId: String, rawToken: String) -> Deeplink? {
        guard let idInt64 = Int64(rawId) else { return nil }
        let id = UserId(idInt64)
        guard let token = try? FriendToken(rawToken) else { return nil }
        return .addFriend(id: id, token: token)
    }
}

private extension URL {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
