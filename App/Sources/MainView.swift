import CommunityRootFeature
import FeedFeature
import NotificationDetailsApi
import ProfileFeature
import SwiftUI

struct MainView<NotificationContent: View>: View {
  @State private var viewModel: MainViewModel
  @State private var hidesCommunityTabBar = false
  @Binding private var route: AppViewModel.MainRoute?
  @Binding private var destination: AppViewModel.Destination?
  private let onOpenNotification: (NotificationSelection) -> Void
  private let notificationContent: (AppViewModel.Destination) -> NotificationContent

  init(
    routeToSignUp: @escaping () -> Void,
    route: Binding<AppViewModel.MainRoute?>,
    destination: Binding<AppViewModel.Destination?>,
    onOpenNotification: @escaping (NotificationSelection) -> Void,
    @ViewBuilder notificationContent: @escaping (AppViewModel.Destination) -> NotificationContent
  ) {
    let mainModel = MainViewModel(routeToSignUp: routeToSignUp)
    viewModel = mainModel
    _route = route
    _destination = destination
    self.onOpenNotification = onOpenNotification
    self.notificationContent = notificationContent
  }

  var body: some View {
    TabView(selection: $viewModel.selectedItem) {
      Tab(.communityTab, systemImage: Constants.community, value: .community) {
        communityView()
      }
      Tab(.mainFeed, systemImage: Constants.feed, value: .feed) {
        NavigationStack { FeedView() }
      }
      Tab(.mainProfile, systemImage: Constants.profile, value: .profile) {
        profileView()
      }
    }
    .animation(.default, value: hidesCommunityTabBar)
    .onChange(of: route, initial: true) {
      guard let route else { return }
      viewModel.open(route, onOpenNotification: onOpenNotification)
      self.route = nil
    }
  }
}

private extension MainView {
  private func communityView() -> some View {
    NavigationStack {
      CommunityRootView(
        model: viewModel.communityModel,
        hidesTabBar: $hidesCommunityTabBar
      )
      .navigationDestination(item: $destination) { destination in
        notificationContent(destination)
      }
    }
  }

  private func profileView() -> some View {
    NavigationStack {
      let profile = ProfileView.SelfProfile(routeToSignUp: viewModel.routeToSignUp)
      ProfileView(mode: .selfProfile(profile))
    }
  }
}

private enum Constants {
  static let community = "text.bubble"
  static let feed = "newspaper"
  static let profile = "person.crop.circle"
}
