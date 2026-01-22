import SwiftUI

@MainActor
@Observable
class DeeplinkRouter {
    var pending: Transaction? = nil

    func begin(deeplink: Deeplink) {
        let transaction = Transaction(deeplink: deeplink)
        pending = transaction
    }

    @discardableResult
    func complete(transaction: Transaction) -> Bool {
        guard pending?.id == transaction.id else { return false }
        pending = nil
        return true
    }

    struct Transaction: Identifiable {
        let id = UUID()
        let deeplink: Deeplink
    }

    struct Listener: Identifiable {
        let id = UUID()
        let block: (Deeplink) -> Bool
    }

    struct Cancellation {
        let cancel: () -> Void
    }

    enum Deeplink {
        case addFriend(id: UserId, token: FriendToken)
    }
}

extension DeeplinkRouter.Deeplink {
    static let addFriend: Regex<(Substring, Substring, Substring)> =
        try! Regex("friendly://add/(.*)/(.*)")

    static func of(url: URL) -> DeeplinkRouter.Deeplink? {
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

struct DeeplinkEnvironmentKey: EnvironmentKey {
    static let defaultValue: DeeplinkRouter? = nil
}

extension EnvironmentValues {
    var deeplinkRouter: DeeplinkRouter? {
        get { self[DeeplinkEnvironmentKey.self] }
        set { self[DeeplinkEnvironmentKey.self] = newValue }
    }
}

private struct WithDeeplinkModifier: ViewModifier {
    let router = DeeplinkRouter()

    func body(content: Content) -> some View {
        return content
            .onOpenURL { url in
                guard let deeplink = DeeplinkRouter.Deeplink.of(url: url) else {
                    return
                }
                router.begin(deeplink: deeplink)
            }
            .environment(\.deeplinkRouter, router)
    }
}

private struct OnDeeplinkModifier: ViewModifier {
    @Environment(\.deeplinkRouter) var router
    let block: (DeeplinkRouter.Deeplink) -> Bool

    func body(content: Content) -> some View {
        guard let router = router else {
            fatalError("Wrap root view with .withDeeplinkRouter()")
        }
        return content.onChange(of: router.pending?.id) {
            guard let transaction = router.pending else { return }
            let shouldComplete = block(transaction.deeplink)
            if shouldComplete {
                router.complete(transaction: transaction)
            }
        }
    }
}

extension View {
    func withDeeplinkRouter() -> some View {
        return modifier(WithDeeplinkModifier())
    }

    /// Return false from `block` if transaction should continue in some other
    /// view.
    func onDeeplink(
        block: @escaping (DeeplinkRouter.Deeplink) -> Bool,
    ) -> some View {
        return modifier(OnDeeplinkModifier(block: block))
    }
}
