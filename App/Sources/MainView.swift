import CommunityRootFeature
import FeedFeature
import FriendlyUIKit
import NetworkFeature
import ProfileFeature
import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @State private var hidesCommunityTabBar = false
    @Binding private var route: ContentViewModel.MainRoute?

    init(
        routeToSignUp: @escaping () -> Void,
        route: Binding<ContentViewModel.MainRoute?>,
    ) {
        let mainModel = MainViewModel(routeToSignUp: routeToSignUp)
        viewModel = mainModel
        _route = route
    }

    var body: some View {
        TabView(selection: $viewModel.selectedItem) {
            Tab(.communityTab, systemImage: Constants.community, value: .community) {
                CommunityRootView(
                    model: viewModel.communityModel,
                    hidesTabBar: $hidesCommunityTabBar
                )
            }
            Tab(
                .mainFeed,
                systemImage: "newspaper",
                value: .feed,
            ) {
                RouterView { router in
                    FeedView(router: router)
                }
            }

            Tab(
                .mainNetwork,
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
                .mainProfile,
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
        .animation(.default, value: hidesCommunityTabBar)
        .onChange(of: route, initial: true) {
            guard let route else { return }
            viewModel.open(route)
            self.route = nil
        }
    }
}

private enum Constants {
  static let community = "text.bubble"
}
