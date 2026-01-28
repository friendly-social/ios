import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @Binding private var addFriend: AddFriendCommand?

    init(
        routeToSignUp: @escaping () -> Void,
        addFriend: Binding<AddFriendCommand?>,
    ) {
        viewModel = MainViewModel(routeToSignUp: routeToSignUp)
        _addFriend = addFriend
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
                        addFriend: $viewModel.addFriend,
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
        .onChange(of: addFriend == nil, initial: true) {
            guard let addFriend = addFriend else { return }
            viewModel.command(addFriend: addFriend)
            self.addFriend = nil
        }
    }
}

