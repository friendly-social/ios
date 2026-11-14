import CommunityRootFeature
import NotificationDetailsApi
import SwiftUI

@MainActor
@Observable
final class MainViewModel {
  var selectedItem: Tab = .community
  let routeToSignUp: () -> Void
  let communityModel: CommunityRootViewModel

  init(routeToSignUp: @escaping () -> Void) {
    self.routeToSignUp = routeToSignUp
    self.communityModel = CommunityRootViewModel(onSessionExpired: routeToSignUp)
  }

  func open(
    _ route: AppViewModel.MainRoute,
    onOpenNotification: (NotificationSelection) -> Void
  ) {
    switch route {
    case .community: selectedItem = .community
    case .feed: selectedItem = .feed
    case let .notification(selection):
      selectedItem = .community
      communityModel.dismissNavigation()
      onOpenNotification(selection)
    }
  }

  enum Tab: Hashable {
    case community
    case feed
    case profile
  }
}
