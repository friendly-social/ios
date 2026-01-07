import SwiftUI

@Observable
class ContentViewModel {
    private(set) var destination: Destination = .empty
    private let storage: Storage = .shared

    func appear() {
        do {
            if try storage.hasAuthorization() {
                destination = .main
            } else {
                destination = .signUp
            }
        } catch {
            try? storage.clearAuthorization()
            destination = .signUp
        }
    }

    func onSignUp() {
        destination = .main
    }

    enum Destination : Hashable {
        case empty
        case signUp
        case main
    }
}
