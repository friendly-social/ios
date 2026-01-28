import SwiftUI

@Observable
class ContentViewModel {
    private(set) var destination: Destination = .empty
    private let storage: Storage = .shared

    var addFriend: AddFriendCommand? = nil

    func appear() {
        do {
            if try storage.hasAuthorization() {
                destination = .main
            } else {
                destination = .signUp
            }
        } catch {
            storage.clearAuthorization()
            destination = .signUp
        }
    }

    func onSignUp() {
        destination = .main
    }

    func routeToSignUp() {
        appear()
    }

    func onAddFriend(id: UserId, token: FriendToken) {
        addFriend = AddFriendCommand(id: id, token: token)
    }

    enum Destination: Hashable {
        case empty
        case signUp
        case main
    }
}
