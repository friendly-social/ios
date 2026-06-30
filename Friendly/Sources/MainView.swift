import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @Binding private var route: ContentViewModel.MainRoute?

    init(
        routeToSignUp: @escaping () -> Void,
        route: Binding<ContentViewModel.MainRoute?>,
    ) {
        viewModel = MainViewModel(routeToSignUp: routeToSignUp)
        _route = route
    }

    var body: some View {
        TabView(selection: $viewModel.selectedItem) {
            Tab(
                "main_feed",
                systemImage: "newspaper",
                value: .feed,
            ) {
                RouterView { router in
                    FeedView(router: router)
                }
            }

            Tab(
                "main_network",
                systemImage: "person.3",
                value: .network,
            ) {
                RouterView { router in
                    NetworkView(
                        router: router,
                    )
                }
            }

            Tab(
                "main_profile",
                systemImage: "person.crop.circle",
                value: .profile,
            ) {
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
        .onChange(of: route, initial: true) {
            guard let route else { return }
            switch route {
            case .feed:
                viewModel.showFeed()
            }
            self.route = nil
        }
    }
}
