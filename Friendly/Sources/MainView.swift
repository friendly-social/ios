import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel

    init(routeToSignUp: @escaping () -> Void) {
        viewModel = MainViewModel(routeToSignUp: routeToSignUp)
    }

    var body: some View {
        TabView {
            Tab("main_feed", systemImage: "newspaper") {
                RouterView { _ in
                    FeedView()
                }
            }
            Tab("main_network", systemImage: "person.3") {
                RouterView { router in
                    NetworkView(router: router)
                }
            }
            Tab("main_profile", systemImage: "person.crop.circle") {
                RouterView { router in
                    let selfProfile = ProfileView.SelfProfile(
                        routeToSignUp: viewModel.routeToSignUp,
                    )
                    ProfileView(
                        router: router,
                        mode: .selfProfile(selfProfile),
                    )
                }
            }
        }
    }
}

