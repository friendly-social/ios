import CommunityRootFeature
import SwiftUI

@MainActor
@Observable
class MainViewModel {
    var selectedItem: Tab = .community
    let routeToSignUp: () -> Void
    let communityModel: CommunityRootViewModel

    init(routeToSignUp: @escaping () -> Void) {
        self.routeToSignUp = routeToSignUp
        self.communityModel = CommunityRootViewModel(onSessionExpired: routeToSignUp)
    }

    func showFeed() {
        selectedItem = .feed
    }

    func open(_ route: ContentViewModel.MainRoute) {
        switch route {
        case .community: selectedItem = .community
        case .feed: selectedItem = .feed
        }
    }

    enum Tab: Hashable {
        case community
        case feed
        case network
        case profile
    }
}
