import SwiftUI

struct MainView: View {
    private let viewModel: MainViewModel

    init(routeToSignUp: @escaping () -> Void) {
        viewModel = MainViewModel(routeToSignUp: routeToSignUp)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        TabView {
            Tab("main_feed", systemImage: "newspaper") {
                FeedView()
            }
            Tab("main_network", systemImage: "person.3") {
                NetworkView()
            }
            Tab("main_profile", systemImage: "person.crop.circle") {
                ProfileView(routeToSignUp: viewModel.routeToSignUp)
            }
        }
    }
}
