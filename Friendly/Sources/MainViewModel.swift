import SwiftUI

@Observable
class MainViewModel {
    var selectedItem: Tab = .feed
    var addFriend: AddFriendCommand? = nil
    let routeToSignUp: () -> Void

    init(routeToSignUp: @escaping () -> Void) {
        self.routeToSignUp = routeToSignUp
    }

    func command(addFriend: AddFriendCommand) {
        self.selectedItem = .network
        self.addFriend = addFriend
    }

    enum Tab: Hashable {
        case feed
        case network
        case profile
    }
}
