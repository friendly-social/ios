import SwiftUI

@Observable
class MainViewModel {
    let routeToSignUp: () -> Void

    init(routeToSignUp: @escaping () -> Void) {
        self.routeToSignUp = routeToSignUp
    }
}
