import SwiftUI

@Observable
class MainViewModel {
    var selectedItem: Tab = .feed
    let routeToSignUp: () -> Void

    init(routeToSignUp: @escaping () -> Void) {
        self.routeToSignUp = routeToSignUp
    }

    func showFeed() {
        selectedItem = .feed
    }

    enum Tab: Hashable {
        case feed
        case network
        case profile
    }
}
