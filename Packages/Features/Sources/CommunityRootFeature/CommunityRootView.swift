import ActivityRootFeature
import CommunityFeature
import SwiftUI

@MainActor
public struct CommunityRootView: View {
  @Bindable private var model: CommunityRootViewModel
  @Binding private var hidesTabBar: Bool

  public init(model: CommunityRootViewModel, hidesTabBar: Binding<Bool>) {
    self.model = model
    self._hidesTabBar = hidesTabBar
  }

  public var body: some View {
    contentView()
      .onAppear(perform: model.start)
  }
}

private extension CommunityRootView {
  private func contentView() -> some View {
    NavigationStack {
      feedContent()
    }
    .toolbarVisibility(hidesTabBar ? .hidden : .automatic, for: .tabBar)
  }

  @ViewBuilder
  private func feedContent() -> some View {
    if let feed = model.feed {
      CommunityView(
        model: feed, avatarURL: feed.avatarURL, hidesTabBar: $hidesTabBar
      ) {
        ActivityRootView(onUnauthorized: model.onSessionExpired)
      }
    } else {
      ContentUnavailableView(.communitySignInRequired, systemImage: Constants.signIn)
    }
  }

}

private enum Constants {
  static let signIn = "person.crop.circle.badge.exclamationmark"
}
