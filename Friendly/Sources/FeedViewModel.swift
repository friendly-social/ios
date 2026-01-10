import SwiftUI

@Observable
class FeedViewModel {
    private let storage: Storage = .shared
    private let networkClient: NetworkClient = .meetacy

    var state: State = .loading

    private var firstAppear = true
    func appear() {
        guard firstAppear else { return }
        firstAppear = false
        Task {
            do {
                let authorization = try storage.loadAuthorization()
                state = .ioError
            } catch {
                state = .ioError
            }
        }
    }

    enum State {
        case loading
        case success(Success)
        case ioError
    }

    struct Success {
    }
}
