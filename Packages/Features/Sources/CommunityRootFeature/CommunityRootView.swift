import CommunityFeature
import FriendlyUIKit
import ProfileFeature
import SwiftUI

@MainActor
public struct CommunityRootView: View {
  @Bindable var model: CommunityRootViewModel
  @Binding var hidesTabBar: Bool

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
    feedContent()
      .toolbar(hidesTabBar ? .hidden : .automatic, for: .tabBar)
      .sheet(item: $model.author) { author in authorView(author) }
  }

  @ViewBuilder
  private func feedContent() -> some View {
    if let feed = model.feed {
      CommunityView(
        model: feed, avatarURL: feed.avatarURL, hidesTabBar: $hidesTabBar,
        openAuthor: model.openAuthor)
    } else {
      ContentUnavailableView(.communitySignInRequired, systemImage: Constants.signIn)
    }
  }

  private func authorView(_ author: CommunityRootViewModel.AuthorDestination) -> some View {
    RouterView { router in
      ProfileView(router: router, mode: .otherProfile(author.profile))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(.communityClose, systemImage: Constants.close) { model.closeAuthor() }
          }
        }
    }
  }
}

private enum Constants {
  static let signIn = "person.crop.circle.badge.exclamationmark"
  static let close = "xmark"
}
