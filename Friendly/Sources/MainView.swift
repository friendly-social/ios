import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel

    init(routeToSignUp: @escaping () -> Void) {
        viewModel = MainViewModel(routeToSignUp: routeToSignUp)
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
                    NetworkView(router: router)
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
        .onDeeplink { deeplink in
            if case .addFriend = deeplink {
                viewModel.onAddFriendDeeplink()
            }
            return false
        }
    }
}

