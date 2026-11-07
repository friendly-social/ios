import CommunityRootFeature
import FeedFeature
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
        systemImage: Constants.feed,
        value: .feed,
      ) {
        NavigationStack {
          FeedView()
        }
      }

      Tab(
        .mainProfile,
        systemImage: Constants.profile,
        value: .profile,
      ) {
        NavigationStack {
          let selfProfile = ProfileView.SelfProfile(
            routeToSignUp: viewModel.routeToSignUp,
          )
          ProfileView(
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
  static let feed = "newspaper"
  static let profile = "person.crop.circle"
}
